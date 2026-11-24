import '../../../core/api/api_exception.dart';
import '../../../design_system/copy/copy.dart';

/// What a refused deal means to the host, from the server's answer
/// (`apps/onuw/deal.py`'s `deal_refusal`: the table is not waiting, or the
/// settings' errors for this many players). Not [answered]: the phone could
/// not reach the server ("Not sent."). Answered with no [why]: the server
/// gave no reason worth saying, so nothing is said; the button showed
/// `deal.ok`, so a refusal means the table changed under the tap, and the
/// lobby read again sets the button.
({bool answered, String? why}) dealRefusalOf(Object error) {
  final (int? status, List<String> details) = switch (error) {
    ValidationException(:final errors) => (
      400,
      [...errors.values.expand((e) => e)],
    ),
    UnhandledHttpException(:final statusCode, :final message) => (
      statusCode,
      [message],
    ),
    NotFoundException() => (404, const <String>[]),
    _ => (null, const <String>[]),
  };
  if (status == null || !serverAnswered(error)) {
    return (answered: false, why: null);
  }
  final why = status == 404
      ? BannerCopy.tableClosed
      : details.contains(_notWaiting)
      ? BannerCopy.lobbyClosed
      : details.any((d) => d.startsWith(_tooFew))
      ? TableCopy.needPlayers
      // Not everyone the table is set for is here: the seats say so.
      : details.any((d) => d.startsWith(_setFor))
      ? null
      : details.any(_deckError.hasMatch)
      ? BannerCopy.deckDoesNotFit
      : null;
  return (answered: true, why: why);
}

/// The server's refusal words (`deal.py`, `validate_onuw_settings`).
const _notWaiting = 'Lobby is not in waiting state.';
const _tooFew = 'At least 3 players required';
const _setFor = 'The table is set for';
final _deckError = RegExp(
  r'^(Total role count|Masons must|Unknown role|Count for|.* requires at least|.* allows at most)',
);
