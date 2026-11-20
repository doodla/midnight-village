import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/debug/debug_models.dart';
import '../../../core/debug/debug_oracle.dart';
import '../../../core/debug/debug_providers.dart';
import '../../../core/debug/debug_table_controller.dart';
import '../../../core/router/routes.dart';
import '../../../design_system/models/role.dart';
import '../../../design_system/teach/learned_store.dart';
import '../../lobby/domain/role_config.dart';

/// DEBUG-ONLY developer toolbar (contract §D3), reachable at `/debug` ONLY when
/// const [Env.isDev] is true (the route is not registered in prod).
///
/// Lets a human spin up a forced-assignment table (as
/// every table the app opens), switch to any player's perspective, watch all
/// players' ground truth via the oracle god panel, auto-drive everyone else,
/// and reset what this device has learned.
///
/// IMPORTANT: the perspective switcher and god panel show other players' true
/// roles — this screen is the human-facing analogue of the DEBUG-gated oracle.
/// It is gated by const [Env.isDev] AND only ever reads ground truth through
/// the DEBUG-gated `debug-state` endpoint, so prod cannot reach it.
class DebugToolbarScreen extends ConsumerStatefulWidget {
  const DebugToolbarScreen({super.key});

  @override
  ConsumerState<DebugToolbarScreen> createState() => _DebugToolbarScreenState();
}

class _DebugToolbarScreenState extends ConsumerState<DebugToolbarScreen> {
  int _playerCount = 5;
  String? _selectedPreset;
  DebugTable? _table;
  DebugOracleState? _oracle;
  bool _busy = false;
  String? _status;

  /// The player whose phone this is now (the last "Become"); auto-drive
  /// acts for everyone else. Null: nobody chosen yet, so everyone.
  int? _perspective;

  // Forced-assignment editor: player index → role name, and the 3 center cards.
  final Map<int, String> _playerRoleEditor = {};
  final List<String> _centerEditor = [];

  DebugTableController get _controller =>
      ref.read(debugTableControllerProvider);

  Map<RoleId, int> get _selectedPresetRoles {
    final presets = RoleConfig.presetsForPlayerCount(_playerCount);
    final name = _selectedPreset ?? presets.keys.firstOrNull;
    return name == null ? const {} : (presets[name] ?? const {});
  }

  /// Builds the flat list of role slots implied by the selected preset's
  /// counts: playerCount roles for players + 3 for center.
  List<String> get _roleSlots {
    final slots = <String>[];
    _selectedPresetRoles.forEach((role, count) {
      for (var i = 0; i < count; i++) {
        slots.add(role.displayName);
      }
    });
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    // Defense in depth: if somehow reached in prod, show nothing.
    if (!Env.isDev) {
      return const Scaffold(body: Center(child: Text('Disabled')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Toolbar'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      // SingleChildScrollView (not ListView) so all sections build even when
      // off-screen — the perspective switcher / god panel must be reachable by
      // tests and visible after scrolling, not lazily dropped.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _status!,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              _buildTableSetup(),
              const Divider(height: 32),
              if (_table != null) ...[
                _buildPerspectiveSwitcher(_table!),
                const Divider(height: 32),
                _buildGodPanel(),
                const Divider(height: 32),
                _buildAutoDrive(_table!),
                const Divider(height: 32),
              ],
              _buildForgetCues(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Learned cues (first-time play: what this device has been taught)
  // ---------------------------------------------------------------------------

  Widget _buildForgetCues() => Align(
    alignment: Alignment.centerLeft,
    child: OutlinedButton(
      key: const Key('debug-forget-cues'),
      onPressed: () => ref.read(learnedCuesProvider.notifier).reset(),
      child: const Text('Reset learned cues'),
    ),
  );

  // ---------------------------------------------------------------------------
  // Table setup
  // ---------------------------------------------------------------------------

  Widget _buildTableSetup() {
    final presets = RoleConfig.presetsForPlayerCount(_playerCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Table Setup',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Players: '),
            DropdownButton<int>(
              key: const Key('debug-player-count'),
              value: _playerCount,
              items: [
                for (var n = 3; n <= 10; n++)
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: _busy
                  ? null
                  : (n) => setState(() {
                      _playerCount = n ?? 5;
                      _selectedPreset = null;
                      _playerRoleEditor.clear();
                      _centerEditor.clear();
                    }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final name in presets.keys)
              ChoiceChip(
                label: Text(name),
                selected: _selectedPreset == name,
                onSelected: _busy
                    ? null
                    : (_) => setState(() {
                        _selectedPreset = name;
                        _seedEditorFromPreset();
                      }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildForcedAssignmentEditor(),
        ElevatedButton(
          key: const Key('debug-create-table'),
          onPressed: _busy || _selectedPreset == null ? null : _createTable,
          child: const Text('Create Table'),
        ),
      ],
    );
  }

  /// Pre-fills the forced-assignment editor from the selected preset: the first
  /// [_playerCount] slots go to players in order, the last 3 to center.
  void _seedEditorFromPreset() {
    final slots = _roleSlots;
    _playerRoleEditor.clear();
    _centerEditor.clear();
    if (slots.length != _playerCount + 3) return;
    for (var i = 0; i < _playerCount; i++) {
      _playerRoleEditor[i] = slots[i];
    }
    _centerEditor.addAll(slots.sublist(_playerCount));
  }

  Widget _buildForcedAssignmentEditor() {
    if (_selectedPreset == null) return const SizedBox.shrink();
    final slots = _roleSlots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Forced Assignment (editable):'),
        for (var i = 0; i < _playerCount; i++)
          Row(
            children: [
              SizedBox(width: 80, child: Text('Player ${i + 1}')),
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _playerRoleEditor[i],
                  items: [
                    for (final role in slots.toSet())
                      DropdownMenuItem(value: role, child: Text(role)),
                  ],
                  onChanged: (v) =>
                      setState(() => _playerRoleEditor[i] = v ?? ''),
                ),
              ),
            ],
          ),
        Text('Center: ${_centerEditor.join(", ")}'),
      ],
    );
  }

  Future<void> _createTable() async {
    final roleCounts = <String, int>{
      for (final entry in _selectedPresetRoles.entries)
        entry.key.displayName: entry.value,
    };
    final names = [for (var i = 0; i < _playerCount; i++) _defaultName(i)];
    final rolesByName = <String, String>{
      for (var i = 0; i < _playerCount; i++)
        names[i]: _playerRoleEditor[i] ?? 'Villager',
    };
    await _run('Creating table...', () async {
      final table = await _controller.createTable(
        playerNames: names,
        roleCounts: roleCounts,
        playerRolesByName: rolesByName,
        centerCards: List.of(_centerEditor),
      );
      setState(() {
        _table = table;
        _perspective = null;
      });
    });
  }

  String _defaultName(int i) =>
      const [
        'Alice',
        'Bob',
        'Carol',
        'Dave',
        'Eve',
        'Frank',
        'Grace',
        'Heidi',
        'Ivan',
        'Judy',
      ].elementAtOrNull(i) ??
      'Player$i';

  // ---------------------------------------------------------------------------
  // Perspective switcher
  // ---------------------------------------------------------------------------

  Widget _buildPerspectiveSwitcher(DebugTable table) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Perspective',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final player in table.players)
          Row(
            children: [
              Expanded(
                child: Text(
                  '${player.displayName}  (${player.role})'
                  '${player.isHost ? "  [host]" : ""}',
                ),
              ),
              TextButton(
                key: Key('debug-switch-${player.userId}'),
                onPressed: _busy ? null : () => _switchTo(player),
                child: const Text('Become'),
              ),
              IconButton(
                tooltip: _controller.isManuallyDisconnected(player.userId)
                    ? 'Reconnect'
                    : 'Disconnect',
                icon: Icon(
                  _controller.isManuallyDisconnected(player.userId)
                      ? Icons.wifi_off
                      : Icons.wifi,
                ),
                onPressed: _busy ? null : () => _toggleConnection(player),
              ),
            ],
          ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _busy ? null : () => _openGame(table),
          child: const Text('Open game screen for current perspective'),
        ),
      ],
    );
  }

  Future<void> _switchTo(DebugPlayer player) async {
    await _run('Switching to ${player.displayName}...', () async {
      await _controller.switchTo(player);
      setState(() => _perspective = player.userId);
    });
  }

  Future<void> _toggleConnection(DebugPlayer player) async {
    final wantConnected = _controller.isManuallyDisconnected(player.userId);
    await _run(
      wantConnected ? 'Reconnecting...' : 'Disconnecting...',
      () => _controller.setConnected(player, wantConnected),
    );
  }

  void _openGame(DebugTable table) =>
      GameRoute(gameId: table.gameId).go(context);

  // ---------------------------------------------------------------------------
  // God panel (live oracle)
  // ---------------------------------------------------------------------------

  Widget _buildGodPanel() {
    final oracle = _oracle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'God Panel (oracle)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              key: const Key('debug-refresh-oracle'),
              icon: const Icon(Icons.refresh),
              onPressed: _busy ? null : _refreshOracle,
            ),
          ],
        ),
        if (oracle == null)
          const Text('Tap refresh to load ground truth.')
        else ...[
          Text('Phase: ${oracle.phase}   Wave: ${oracle.currentWave}'),
          Text('Center: ${oracle.centerCards.join(", ")}'),
          const SizedBox(height: 8),
          for (final p in oracle.players)
            Text(
              '${p.displayName}: ${p.originalRole} → ${p.currentRole}'
              '${p.doppelgangerCopiedRole != null ? " (copied ${p.doppelgangerCopiedRole})" : ""}'
              '  [${p.team}]${p.connected ? "" : "  (offline)"}',
            ),
          const SizedBox(height: 8),
          const Text('Votes:'),
          for (final entry in oracle.votes.entries)
            Text('  ${entry.key} → ${entry.value ?? "—"}'),
          if (oracle.results != null) ...[
            const SizedBox(height: 8),
            Text('Winners: ${oracle.results!.winningTeams.join(", ")}'),
          ],
          const SizedBox(height: 8),
          const Text('Night action log:'),
          for (final a in oracle.nightActionsLog)
            Text(
              '  W${a.wave} #${a.timestampOrder} player ${a.playerId} '
              'as ${a.roleActingAs}: ${a.actionType} '
              '→ ${a.result}',
            ),
        ],
      ],
    );
  }

  Future<void> _refreshOracle() async {
    await _run('Reading oracle...', () async {
      final oracle = await _controller.oracle();
      setState(() => _oracle = oracle);
    });
  }

  // ---------------------------------------------------------------------------
  // Auto-drive
  // ---------------------------------------------------------------------------

  Widget _buildAutoDrive(DebugTable table) {
    final target = _perspective == null
        ? table.host
        : table.playerById(_perspective!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Auto-drive (everyone but this phone)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton(
              key: const Key('debug-everyone-ready'),
              onPressed: _busy
                  ? null
                  : () => _everyoneElse(
                      table,
                      'Everyone ready',
                      (p) => _controller.stagedAs(p, 'ready', {
                        'ready': true,
                      }, lenient: true),
                    ),
              child: const Text('Everyone ready'),
            ),
            ElevatedButton(
              key: const Key('debug-everyone-chooses'),
              onPressed: _busy
                  ? null
                  : () => _everyoneElse(
                      table,
                      'Everyone keeps their card',
                      (p) => _controller.stagedAs(p, 'action', {
                        'action_type': 'choose',
                        'picks': const <Object>[],
                      }, lenient: true),
                    ),
              child: const Text('Everyone keeps their card'),
            ),
            ElevatedButton(
              key: const Key('debug-everyone-votes'),
              onPressed: _busy
                  ? null
                  : () => _everyoneElse(
                      table,
                      'Everyone votes ${target.displayName}',
                      (p) => _controller.stagedAs(p, 'vote', {
                        'target_player_id': p.userId == target.userId
                            ? table.players
                                  .firstWhere((o) => o.userId != p.userId)
                                  .userId
                            : target.userId,
                        'lock': true,
                      }, lenient: true),
                    ),
              child: Text('Everyone votes ${target.displayName}'),
            ),
            ElevatedButton(
              onPressed: _busy ? null : () => _fireTimer(TimerKey.current),
              child: const Text('Fire pending timer'),
            ),
          ],
        ),
      ],
    );
  }

  /// [act] for every player but this phone's, one after the other.
  Future<void> _everyoneElse(
    DebugTable table,
    String what,
    Future<void> Function(DebugPlayer p) act,
  ) async {
    await _run('$what...', () async {
      for (final p in table.players) {
        if (p.userId == _perspective) continue;
        await act(p);
      }
    });
  }

  Future<void> _fireTimer(TimerKey key) async {
    await _run('Firing timer ${key.key}...', () async {
      await _controller.fireTimer(key);
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _run(String status, Future<void> Function() body) async {
    setState(() {
      _busy = true;
      _status = status;
    });
    try {
      await body();
      if (mounted) setState(() => _status = 'Done: $status');
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
