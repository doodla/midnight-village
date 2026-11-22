"""Run with: python3 .claude/guardrails/tests/test_guardrails.py"""
import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path
from unittest import mock

GUARDRAILS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GUARDRAILS))
sys.path.insert(0, str(GUARDRAILS.parents[1] / "tool"))  # repo_files: the repo's tracked files

import runner  # noqa: E402
from rules import subagent_model_effort as sme  # noqa: E402

OPTS = {"mode": "enforce", "on_error": "closed", "allowed_models": ["opus", "sonnet"], "allow_forks": False}
ENFORCE = {"rules": {"subagent_model_effort": OPTS}}


def pre(tool, tool_input, **extra):
    return {"hook_event_name": "PreToolUse", "tool_name": tool, "tool_input": tool_input,
            "permission_mode": "auto", **extra}


def workflow(script):
    return pre("Workflow", {"script": textwrap.dedent(script)})


class IsolatedEnv(unittest.TestCase):
    """Point project and home dirs at temp dirs so real agent definitions don't leak in."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.project, self.home = root / "project", root / "home"
        self.project.mkdir()
        self.home.mkdir()
        patches = [
            mock.patch.dict(os.environ, {"CLAUDE_PROJECT_DIR": str(self.project), "HOME": str(self.home)}),
            mock.patch.object(runner, "LOG_PATH", root / "logs" / "decisions.jsonl"),
        ]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        self.addCleanup(self.tmp.cleanup)
        os.environ.pop("GUARDRAILS_OFF", None)

    def define_agent(self, name, where="project", **fields):
        base = self.project / ".claude" if where == "project" else self.home / ".claude"
        d = base / "agents"
        d.mkdir(parents=True, exist_ok=True)
        fm = "\n".join(f"{k}: {v}" for k, v in {"name": name, **fields}.items())
        (d / f"{name}.md").write_text(f"---\n{fm}\n---\nYou are {name}.\n")

    def decide(self, hook, config=ENFORCE):
        denials, warnings, _ = runner.evaluate(hook, config)
        return runner.render(hook["hook_event_name"], denials, warnings)

    def assertDenied(self, hook, *fragments, config=ENFORCE):
        out = self.decide(hook, config)
        self.assertIsNotNone(out, "expected a deny, got silence")
        hso = out["hookSpecificOutput"]
        self.assertEqual(hso["permissionDecision"], "deny")
        for f in fragments:
            self.assertIn(f, hso["permissionDecisionReason"])
        return hso["permissionDecisionReason"]

    def assertSilent(self, hook, config=ENFORCE):
        self.assertIsNone(self.decide(hook, config))


class AgentToolTests(IsolatedEnv):
    def test_missing_both(self):
        self.assertDenied(pre("Agent", {"prompt": "x"}), "model and effort")

    def test_missing_effort(self):
        reason = self.assertDenied(pre("Agent", {"prompt": "x", "model": "sonnet"}), "must set effort")
        self.assertNotIn("set model and", reason)

    def test_both_set(self):
        self.assertSilent(pre("Agent", {"prompt": "x", "model": "sonnet", "effort": "low"}))

    def test_legacy_task_tool_name(self):
        self.assertDenied(pre("Task", {"prompt": "x"}), "Task call")

    def test_definition_pins_both(self):
        self.define_agent("scout", model="sonnet", effort="low")
        self.assertSilent(pre("Agent", {"prompt": "x", "subagent_type": "scout"}))

    def test_definition_pins_model_only(self):
        self.define_agent("scout", model="sonnet")
        self.assertDenied(pre("Agent", {"prompt": "x", "subagent_type": "scout"}), "must set effort")

    def test_definition_inherit_does_not_count(self):
        self.define_agent("scout", model="inherit", effort="low")
        self.assertDenied(pre("Agent", {"prompt": "x", "subagent_type": "scout"}), "must set model")

    def test_user_level_definition(self):
        self.define_agent("reviewer", where="home", model="opus", effort="high")
        self.assertSilent(pre("Agent", {"prompt": "x", "subagent_type": "reviewer"}))

    def test_unknown_or_builtin_type_needs_both(self):
        self.assertDenied(pre("Agent", {"prompt": "x", "subagent_type": "general-purpose"}), "model and effort")

    def test_other_tools_ignored(self):
        self.assertSilent(pre("Bash", {"command": "ls"}))


class WorkflowTests(IsolatedEnv):
    def test_all_calls_pinned(self):
        self.assertSilent(workflow("""
            const a = await agent('a', {model: 'opus', effort: 'high'})
            const b = await agent(`b ${x}`, {schema: S, effort: 'low', model: 'sonnet'})
        """))

    def test_reports_each_bad_call_by_line(self):
        reason = self.assertDenied(workflow("""
            const a = await agent('ok', {model: 'opus', effort: 'high'})
            const b = await agent('no opts')
            const c = await agent('half', {model: 'sonnet'})
        """), "line 3: missing model, effort", "line 4: missing effort")
        self.assertNotIn("line 2", reason)

    def test_ignores_comments_strings_and_lookalikes(self):
        self.assertSilent(workflow("""
            // agent('commented out')
            /* agent('block comment') */
            const u = 'https://x.y // agent("in a string")'
            const w = await workflow('other')
            const s = await subagent('not ours')
            const t = await obj.agent('method call')
        """))

    def test_keys_inside_prompt_text_do_not_count(self):
        self.assertDenied(workflow("""
            await agent('use model: opus and effort: high', {schema: S})
        """), "line 2")

    def test_parens_inside_template_expressions(self):
        self.assertSilent(workflow("""
            await agent(`find (bugs) in ${f(g(x))}`, {model: 'sonnet', effort: 'low'})
        """))

    def test_nested_in_parallel(self):
        self.assertDenied(workflow("""
            await parallel(xs.map(x => () => agent(`v ${x}`, {schema: V})))
        """), "line 2")

    def test_nested_call_options_do_not_satisfy_outer_call(self):
        reason = self.assertDenied(workflow("""
            await agent(build(agent('x', {model: 'opus', effort: 'b'})))
        """), "line 2: missing model, effort in agent(build(")
        self.assertEqual(reason.count("line 2"), 1)

    def test_nested_agent_type_does_not_satisfy_outer_call(self):
        self.define_agent("scout", model="sonnet", effort="low")
        self.assertDenied(workflow("""
            await agent(build(agent('x', {agentType: 'scout'})))
        """), "missing model, effort in agent(build(")

    def test_outer_options_after_nested_call_still_count(self):
        self.assertSilent(workflow("""
            await agent(build(agent('x', {model: 'opus', effort: 'b'})), {model: 'sonnet', effort: 'd'})
        """))

    def test_variable_opts_rejected(self):
        self.assertDenied(workflow("await agent(p, opts)"), "line 1")

    def test_agent_type_definition_counts(self):
        self.define_agent("scout", model="sonnet", effort="low")
        self.assertSilent(workflow("await agent('a', {agentType: 'scout'})"))

    def test_agent_type_inside_prompt_text_does_not_count(self):
        self.define_agent("scout", model="sonnet", effort="low")
        self.assertDenied(workflow("await agent(\"say agentType: 'scout'\", {schema: S})"), "line 1")

    def test_quoted_agent_type_key(self):
        self.define_agent("scout", model="sonnet", effort="low")
        self.assertSilent(workflow('await agent("a", {"agentType": "scout"})'))

    def test_relative_script_path_uses_hook_cwd(self):
        (self.project / "wf.js").write_text("await agent('a')")
        self.assertDenied(pre("Workflow", {"scriptPath": "wf.js"}, cwd=str(self.project)), "line 1")

    def test_agent_type_partial_definition(self):
        self.define_agent("scout", model="sonnet")
        self.assertDenied(workflow("await agent('a', {agentType: 'scout'})"), "missing effort")

    def test_script_path(self):
        path = self.project / "wf.js"
        path.write_text("await agent('a')")
        self.assertDenied(pre("Workflow", {"scriptPath": str(path)}), "line 1")

    def test_named_workflow_not_checked(self):
        self.assertSilent(pre("Workflow", {"name": "saved"}))

    def test_missing_script_path_left_to_tool(self):
        self.assertSilent(pre("Workflow", {"scriptPath": str(self.project / "nope.js")}))


class ModelAllowListTests(IsolatedEnv):
    """The pinned model, from the call or the definition, must be an allowed family."""

    def agent(self, **kw):
        return pre("Agent", {"prompt": "x", "effort": "low", **kw})

    def test_allowed_aliases(self):
        for model in ("opus", "sonnet", "Opus", "SONNET"):
            self.assertSilent(self.agent(model=model))

    def test_allowed_full_ids_and_suffixes(self):
        for model in ("claude-opus-4-1-20250805", "claude-sonnet-4-5", "us.anthropic.claude-sonnet-4-5-v1:0",
                      "opus[1m]", "sonnet[1m]"):
            self.assertSilent(self.agent(model=model))

    def test_haiku_blocked_with_fix(self):
        self.assertDenied(self.agent(model="haiku"), "'haiku'", "from the call", "`opus` or `sonnet`")

    def test_haiku_full_id_blocked(self):
        self.assertDenied(self.agent(model="claude-haiku-4-5-20251001"), "not allowed")

    def test_unknown_and_inherit_blocked(self):
        for model in ("inherit", "gpt-4", "fable", "default"):
            self.assertDenied(self.agent(model=model), "not allowed")

    def test_non_string_model_blocked(self):
        self.assertDenied(self.agent(model=["opus"]), "not allowed")

    def test_missing_model_says_what_to_set(self):
        self.assertDenied(pre("Agent", {"prompt": "x", "effort": "low"}), "must set model", "`opus` or `sonnet`")

    def test_builtin_types_need_model_in_call(self):
        for t in ("general-purpose", "Explore", "Plan", "web-fetch", "claude-code-guide", "statusline-setup"):
            self.assertDenied(pre("Agent", {"prompt": "x", "subagent_type": t, "effort": "low"}), "must set model")
            self.assertDenied(pre("Agent", {"prompt": "x", "subagent_type": t}), "model and effort")
            self.assertSilent(pre("Agent", {"prompt": "x", "subagent_type": t, "model": "sonnet", "effort": "low"}))
            self.assertDenied(pre("Agent", {"prompt": "x", "subagent_type": t, "model": "haiku", "effort": "low"}),
                              "not allowed")

    def test_definition_model_allowed(self):
        self.define_agent("rev", model="opus", effort="high")
        self.assertSilent(pre("Agent", {"prompt": "x", "subagent_type": "rev"}))

    def test_definition_haiku_blocked(self):
        self.define_agent("scout", model="haiku", effort="low")
        self.assertDenied(pre("Agent", {"prompt": "x", "subagent_type": "scout"}),
                          "'haiku'", "agent definition of 'scout'")

    def test_call_model_overrides_bad_definition(self):
        self.define_agent("scout", model="haiku", effort="low")
        self.assertSilent(pre("Agent", {"prompt": "x", "subagent_type": "scout", "model": "sonnet"}))

    def test_call_model_haiku_blocked_even_if_definition_ok(self):
        self.define_agent("rev", model="opus", effort="high")
        self.assertDenied(pre("Agent", {"prompt": "x", "subagent_type": "rev", "model": "haiku"}), "from the call")

    def test_real_config_haiku_still_needs_effort_and_no_fork(self):
        real = {"rules": {"subagent_model_effort": runner.load_config()["rules"]["subagent_model_effort"]}}
        self.assertSilent(self.agent(model="haiku"), real)
        self.assertDenied(pre("Agent", {"prompt": "x", "model": "haiku"}), "must set effort", config=real)
        self.assertDenied(pre("Agent", {"prompt": "x", "subagent_type": "fork"}), "forks are not allowed", config=real)

    def test_haiku_allowed_when_listed(self):
        cfg = {"rules": {"subagent_model_effort": {**OPTS, "allowed_models": ["haiku"]}}}
        self.assertSilent(self.agent(model="haiku"), cfg)
        self.assertDenied(self.agent(model="opus"), "not allowed", config=cfg)

    def test_default_allow_list_when_unconfigured(self):
        cfg = {"rules": {"subagent_model_effort": {"mode": "enforce"}}}
        self.assertSilent(self.agent(model="opus"), cfg)
        self.assertDenied(self.agent(model="haiku"), "not allowed", config=cfg)

    def test_real_config_allows_opus_sonnet_and_haiku_on_trial(self):
        opts = runner.load_config()["rules"]["subagent_model_effort"]
        self.assertEqual(sorted(opts["allowed_models"]), ["haiku", "opus", "sonnet"])
        self.assertIs(opts["allow_forks"], False)
        self.assertEqual(opts["mode"], "enforce")

    def test_real_project_agent_definitions_are_pinned_and_allowed(self):
        """Every agent in the repo's .claude/agents/ passes the rule with no model in the call."""
        from agent_defs import frontmatter
        from repo_files import checkout_files
        found = checkout_files(GUARDRAILS.parent / "agents", suffixes=(".md",))
        self.assertTrue(found)
        for path in found:
            fields = frontmatter(path.read_text())
            self.assertTrue(sme.is_allowed(fields.get("model"), OPTS), f"{path.name}: model {fields.get('model')!r}")
            self.assertTrue(fields.get("effort"), f"{path.name}: no effort pinned")


class ForkTests(IsolatedEnv):
    def test_fork_blocked(self):
        reason = self.assertDenied(pre("Agent", {"prompt": "x", "subagent_type": "fork"}),
                                   "forks are not allowed", "fresh agent", "`opus` or `sonnet`")
        self.assertIn("inherits the parent", reason)

    def test_fork_blocked_even_with_model_and_effort(self):
        self.assertDenied(pre("Agent", {"prompt": "x", "subagent_type": "fork", "model": "sonnet", "effort": "low"}),
                          "forks are not allowed")

    def test_fork_blocked_via_task_tool(self):
        self.assertDenied(pre("Task", {"prompt": "x", "subagent_type": "fork"}), "Task call: forks are not allowed")

    def test_fork_allowed_by_config(self):
        cfg = {"rules": {"subagent_model_effort": {**OPTS, "allow_forks": True}}}
        self.assertSilent(pre("Agent", {"prompt": "x", "subagent_type": "fork"}), cfg)

    def test_fork_in_workflow_blocked(self):
        self.assertDenied(workflow("await agent('a', {agentType: 'fork', model: 'sonnet', effort: 'low'})"),
                          "line 1: forks are not allowed")


class WorkflowModelTests(IsolatedEnv):
    def test_allowed_literals_all_quote_styles(self):
        self.assertSilent(workflow("""
            await agent('a', {model: 'opus', effort: 'high'})
            await agent("b", {model: "claude-sonnet-4-5", effort: 'low'})
            await agent(`c`, {effort: 'low', model: `sonnet`})
            await agent('d', {
              effort: 'low',
              model: 'sonnet'
            })
        """))

    def test_haiku_blocked_with_line(self):
        self.assertDenied(workflow("""
            await agent('ok', {model: 'sonnet', effort: 'low'})
            await agent('bad', {model: 'haiku', effort: 'low'})
        """), "line 3: model 'haiku' is not allowed", "`opus` or `sonnet`")

    def test_non_literal_model_is_a_violation(self):
        for expr in ("m", "cfg.model", "pick()", "`s${x}`", "cond ? 'opus' : 'haiku'", "'opus' + x"):
            self.assertDenied(workflow(f"await agent('a', {{model: {expr}, effort: 'low'}})"),
                              "model must be a string literal")

    def test_model_inside_prompt_text_ignored(self):
        self.assertDenied(workflow("await agent(\"use model: 'sonnet' effort: 'low'\", {schema: S})"),
                          "missing model, effort")

    def test_definition_model_checked_when_not_inline(self):
        self.define_agent("scout", model="haiku", effort="low")
        self.assertDenied(workflow("await agent('a', {agentType: 'scout'})"), "definition 'scout' runs on model 'haiku'")

    def test_inline_model_overrides_definition_model(self):
        self.define_agent("scout", model="haiku", effort="low")
        self.assertSilent(workflow("await agent('a', {agentType: 'scout', model: 'opus'})"))

    def test_allowed_definition_model_passes(self):
        self.define_agent("rev", model="opus", effort="high")
        self.assertSilent(workflow("await agent('a', {agentType: 'rev'})"))


class RunnerTests(IsolatedEnv):
    HOOK = pre("Agent", {"prompt": "x"})

    def test_warn_mode_adds_context_without_deny(self):
        out = self.decide(self.HOOK, {"rules": {"subagent_model_effort": {"mode": "warn"}}})
        hso = out["hookSpecificOutput"]
        self.assertNotIn("permissionDecision", hso)
        self.assertIn("subagent_model_effort", hso["additionalContext"])

    def test_off_mode(self):
        self.assertSilent(self.HOOK, {"rules": {"subagent_model_effort": {"mode": "off"}}})

    def test_env_escape_hatch(self):
        with mock.patch.dict(os.environ, {"GUARDRAILS_OFF": "other, subagent_model_effort"}):
            self.assertSilent(self.HOOK)

    def test_never_allows_or_asks(self):
        for hook in (self.HOOK, pre("Agent", {"prompt": "x", "model": "m", "effort": "low"})):
            out = self.decide(hook) or {}
            decision = out.get("hookSpecificOutput", {}).get("permissionDecision")
            self.assertIn(decision, (None, "deny"))

    def crash(self, on_error, mode="enforce"):
        cfg = {"rules": {"subagent_model_effort": {"mode": mode, "on_error": on_error}}}
        with mock.patch.object(sme, "check", side_effect=RuntimeError("boom")):
            return self.decide(self.HOOK, cfg)

    def test_crash_fails_closed(self):
        self.assertIn("crashed", self.crash("closed")["hookSpecificOutput"]["permissionDecisionReason"])

    def test_crash_in_warn_mode_only_warns(self):
        hso = self.crash("closed", mode="warn")["hookSpecificOutput"]
        self.assertNotIn("permissionDecision", hso)
        self.assertIn("crashed", hso["additionalContext"])

    def test_crash_fails_open(self):
        self.assertIsNone(self.crash("open"))

    def test_unknown_rule_fails_closed_without_crashing(self):
        out = self.decide(self.HOOK, {"rules": {"no_such_rule": {"mode": "enforce"}}})
        self.assertIn("no_such_rule crashed", out["hookSpecificOutput"]["permissionDecisionReason"])

    def test_logs_decisions(self):
        denials, warnings, records = runner.evaluate({**self.HOOK, "session_id": "s1"}, ENFORCE)
        runner.log({**self.HOOK, "session_id": "s1"}, records)
        entry = json.loads(runner.LOG_PATH.read_text().splitlines()[0])
        self.assertEqual((entry["rule"], entry["action"], entry["session_id"]), ("subagent_model_effort", "deny", "s1"))
        self.assertEqual(entry["permission_mode"], "auto")

    def run_runner(self, stdin, **env):
        full = {**os.environ, "GUARDRAILS_OFF": "", "GUARDRAILS_LOG": str(runner.LOG_PATH), **env}
        return subprocess.run([sys.executable, str(GUARDRAILS / "runner.py")], input=stdin,
                              capture_output=True, text=True, env=full)

    def test_runner_crash_blocks_with_clear_message(self):
        res = self.run_runner("not json")
        self.assertEqual(res.returncode, 2)
        self.assertIn("Guardrails runner crashed", res.stderr)
        self.assertIn("GUARDRAILS_OFF=runner", res.stderr)

    def test_runner_crash_escape_hatch(self):
        res = self.run_runner("not json", GUARDRAILS_OFF="runner")
        self.assertEqual((res.returncode, res.stderr), (0, ""))

    def test_blocked_spawn_end_to_end_cases(self):
        for model, expected in (("gpt-4", "deny"), ("haiku", None), ("opus", None)):
            res = self.run_runner(json.dumps(pre("Agent", {"prompt": "x", "model": model, "effort": "low"})))
            self.assertEqual(res.returncode, 0, res.stderr)
            got = json.loads(res.stdout)["hookSpecificOutput"]["permissionDecision"] if res.stdout else None
            self.assertEqual(got, expected, model)

    def test_end_to_end_subprocess(self):
        env = {**os.environ, "GUARDRAILS_OFF": "", "GUARDRAILS_LOG": str(runner.LOG_PATH)}
        run = lambda hook: subprocess.run(
            [sys.executable, str(GUARDRAILS / "runner.py")], input=json.dumps(hook),
            capture_output=True, text=True, env=env)
        denied = run(self.HOOK)
        self.assertEqual(denied.returncode, 0, denied.stderr)
        self.assertEqual(json.loads(denied.stdout)["hookSpecificOutput"]["permissionDecision"], "deny")
        ok = run(pre("Agent", {"prompt": "x", "model": "sonnet", "effort": "low"}))
        self.assertEqual((ok.returncode, ok.stdout), (0, ""))


class ConfigConsistencyTests(unittest.TestCase):
    """Catch the easy wiring mistakes: a configured rule that never runs."""

    def setUp(self):
        self.config = runner.load_config()
        settings = json.loads((GUARDRAILS.parent / "settings.json").read_text())
        self.pre_matchers = [
            g.get("matcher", "*") for g in settings["hooks"].get("PreToolUse", [])
            if any("guardrails/runner.py" in h.get("command", "") for h in g["hooks"])
        ]

    def test_every_configured_rule_imports(self):
        import importlib
        for name, opts in self.config["rules"].items():
            rule = importlib.import_module(f"rules.{name}")
            self.assertTrue(callable(rule.check), name)
            self.assertIn(opts.get("mode", "warn"), ("enforce", "warn", "off"), name)
            self.assertIn(opts.get("on_error", "closed"), ("closed", "open"), name)

    def test_settings_matcher_routes_every_rule_tool(self):
        import importlib
        import re
        for name in self.config["rules"]:
            rule = importlib.import_module(f"rules.{name}")
            if "PreToolUse" not in rule.EVENTS:
                continue
            for tool in getattr(rule, "TOOLS", None) or ["*"]:
                routed = any(m == "*" or re.fullmatch(m, tool) for m in self.pre_matchers)
                self.assertTrue(routed, f"{name}: tool {tool} isn't in the PreToolUse matcher")


if __name__ == "__main__":
    unittest.main()
