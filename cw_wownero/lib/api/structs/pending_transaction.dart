import 'dart:ffi';

import 'package:ffi/ffi.dart';

final class PendingTransactionRaw extends Struct {
  @Int64()
  external int amount;

  @Int64()
  external int fee;

  external Pointer<Utf8> hash;

  String getHash() => hash.toDartString();
}

class PendingTransactionDescription {
  PendingTransactionDescription({
    this.amount,
    this.fee,
    this.hash,
    this.pointerAddress,
  });

  final int? amount;
  final int? fee;
  final String? hash;
  final int? pointerAddress;
}
