/// The table code in what a QR code, a pasted link or a typed code holds.
library;

/// A code as the server makes them (`generate_lobby_code`): six of the capitals
/// and digits that are not easily mixed up, so no 0, O, I, 1 or L. A text of
/// any other alphabet or length is not a table's, and starts no join.
const _alphabet = '[A-HJ-KM-NP-Za-hj-km-np-z2-9]';
final _bareCode = RegExp('^$_alphabet{6}\$');

/// `/join/<code>` in a link of any origin (`https://host/join/AB12CD`), or
/// bare (`/join/AB12CD`). The code ends the text or is followed by something
/// that is not a letter or digit (`/`, `?`, `#`, a space).
final _joinPath = RegExp(
  '(?:^|/)join/($_alphabet{6})(?![A-Za-z0-9])',
  caseSensitive: false,
);

/// The table code a scan holds, in capitals: from a table link (any origin)
/// or a bare code, in any case and with any spaces; null for anything else
/// (another web address, a Wi-Fi code, words).
String? tableCodeFrom(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final link = _joinPath.firstMatch(trimmed);
  if (link != null) return link.group(1)!.toUpperCase();
  final bare = trimmed.replaceAll(RegExp(r'\s+'), '');
  return _bareCode.hasMatch(bare) ? bare.toUpperCase() : null;
}
