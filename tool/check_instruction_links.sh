#!/usr/bin/env bash
# The instruction-link check (`just check`, the commit gate with --staged): what it
# checks is said in tool/check_instruction_links.py, which this runs.
# usage: tool/check_instruction_links.sh [--staged] [--fix] [file...]
exec python3 "$(dirname "${BASH_SOURCE[0]}")/check_instruction_links.py" "$@"
