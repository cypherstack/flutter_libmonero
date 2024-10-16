// /// Exception when interacting with a Monero wallet or daemon.
// class LibMoneroError implements Exception {
//   LibMoneroError(this.message, {this.code});
//
//   final int? code;
//   final String message;
//
//   @override
//   String toString() {
//     if (code == null) return message;
//     return '$code: $message';
//   }
// }
