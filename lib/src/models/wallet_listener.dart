class WalletListener {
  WalletListener({
    this.onSyncingUpdate,
    this.onNewBlock,
    this.onBalancesChanged,
    this.onError,
  });

  final void Function({
    required int syncHeight,
    required int nodeHeight,
    String? message,
  })? onSyncingUpdate;

  final void Function(
    int height,
  )? onNewBlock;

  final void Function({
    required int newBalance,
    required int newUnlockedBalance,
  })? onBalancesChanged;

  final void Function(
    Object? error,
    StackTrace? stackTrace,
  )? onError;
}
