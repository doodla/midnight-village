/// The table code in what a QR code, a pasted link or a typed code holds.
library;

/// Six letters and digits, as the typing field takes them.
final _bareCode = RegExp(r'^[A-Za-z0-9]{6}$');

/// `/join/<code>` in a link of any origin (`https://host/join/AB12CD`), or
/// bare (`/join/AB12CD`). The code ends the text or is followed by something
/// that is not a letter or digit (`/`, `?`, `#`, a space).
final _joinPath = RegExp(
  r'(?:^|/)join/([A-Za-z0-9]{6})(?![A-Za-z0-9])',
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
