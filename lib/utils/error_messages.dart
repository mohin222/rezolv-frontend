/// Turns a raw exception (often a technical string like
/// "ClientException with SocketException: Connection refused") into
/// something a user can actually understand.
String friendlyError(Object error) {
  final text = error.toString().toLowerCase();

  if (text.contains('socketexception') ||
      text.contains('connection refused') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable')) {
    return "Can't connect to the server. Check your internet connection and try again.";
  }

  if (text.contains('timeoutexception') || text.contains('timed out')) {
    return 'The request timed out. Please try again.';
  }

  return 'Something went wrong. Please try again.';
}
