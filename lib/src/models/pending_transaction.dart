class PendingTransaction {
  PendingTransaction({
    this.amount,
    this.fee,
    this.txid,
    this.hex,
    this.pointerAddress,
  });

  final int? amount;
  final int? fee;
  final String? txid;
  final String? hex;
  final int? pointerAddress;
}
