/// Why the host role moved.
enum HostChangeReason {
  /// The host's phone dropped and the role passed to a connected player.
  handover,

  /// The original host is back and has the role again.
  returned,

  /// The owner left the table and ownership passed, for good, to another
  /// member. [HostChange.hostId] equals [HostChange.originalHostId]: the new
  /// owner.
  transferred,
}

/// The `host_changed` event, sent on both the lobby and the game channel:
/// `{"type": "host_changed", "host_id", "host_name", "original_host_id",
/// "reason": "handover" | "returned" | "transferred"}`.
///
/// [hostId] is the effective (current) host. Public to the whole table: it
/// says who runs the table, nothing about roles.
class HostChange {
  const HostChange({
    required this.hostId,
    required this.hostName,
    required this.originalHostId,
    required this.reason,
  });

  final int hostId;
  final String hostName;
  final int originalHostId;
  final HostChangeReason reason;

  /// The event as the server sends it (every key always present).
  factory HostChange.fromEvent(Map<String, dynamic> event) => HostChange(
    hostId: event['host_id'] as int,
    hostName: event['host_name'] as String,
    originalHostId: event['original_host_id'] as int,
    reason: HostChangeReason.values.byName(event['reason'] as String),
  );

  @override
  bool operator ==(Object other) =>
      other is HostChange &&
      other.hostId == hostId &&
      other.hostName == hostName &&
      other.originalHostId == originalHostId &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(hostId, hostName, originalHostId, reason);
}

/// Said when a host-only action is refused because the role has just moved.
const String kNoLongerHostMessage = 'You are no longer the host.';

/// A host-only call was refused (403): the role moved to someone else. The
/// owner of the call has already refreshed its state from the server.
class NoLongerHostException implements Exception {
  const NoLongerHostException();

  @override
  String toString() => kNoLongerHostMessage;
}

/// How long the "hosting again" / "is the host now" line and a "no longer
/// the host" line stay.
const Duration kHostNoticeDuration = Duration(seconds: 6);
