/// Why the host role moved.
enum HostChangeReason {
  /// The host's phone dropped and the role passed to a connected player.
  handover,

  /// The original host is back and has the role again.
  returned,
}

/// The `host_changed` event, sent on both the lobby and the game channel:
/// `{"type": "host_changed", "host_id", "host_name", "original_host_id",
/// "reason": "handover" | "returned"}`.
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

  /// Parses the event, or returns null when it is not in the expected shape.
  static HostChange? fromEvent(Map<String, dynamic> event) {
    final hostId = event['host_id'];
    final original = event['original_host_id'];
    final reason = switch (event['reason']) {
      'handover' => HostChangeReason.handover,
      'returned' => HostChangeReason.returned,
      _ => null,
    };
    if (hostId is! int || reason == null) return null;
    return HostChange(
      hostId: hostId,
      hostName: event['host_name'] is String
          ? event['host_name'] as String
          : 'Someone',
      originalHostId: original is int ? original : hostId,
      reason: reason,
    );
  }

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

/// The quiet line everyone sees when the host changes.
///
/// - handover: "Ben is hosting while Ana is away"; for the new host
///   "You are hosting while Ana is away"; for the original host, who sees it
///   once back, "Ben is hosting while you are away".
/// - returned: "Ana is hosting again" / "You are hosting again".
///
/// [originalHostName] is looked up by the caller in the table's player list;
/// without it the line says "the host".
String hostChangeLine({
  required HostChange change,
  required int? viewerId,
  String? originalHostName,
}) {
  final viewerIsHost = viewerId != null && viewerId == change.hostId;
  switch (change.reason) {
    case HostChangeReason.returned:
      return viewerIsHost
          ? 'You are hosting again'
          : '${change.hostName} is hosting again';
    case HostChangeReason.handover:
      final viewerIsOriginal =
          viewerId != null && viewerId == change.originalHostId;
      final who = viewerIsHost ? 'You are' : '${change.hostName} is';
      final away = viewerIsOriginal
          ? 'you are away'
          : '${originalHostName ?? 'the host'} is away';
      return '$who hosting while $away';
  }
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

/// How long the "hosting again" line and a "no longer the host" line stay.
const Duration kHostNoticeDuration = Duration(seconds: 6);
