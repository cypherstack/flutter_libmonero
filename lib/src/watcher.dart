import 'dart:async';

import 'wallet.dart';

enum WalletStatus {
  synced,
  syncing,
  error;
}

class Watcher {
  Watcher({
    required this.wallet,
    required Duration pollingInterval,
    this.onNewTransaction,
    this.onSyncingUpdate,
    this.onError,
  }) : _pollingInterval = pollingInterval;

  final Wallet wallet;
  final void Function()? onNewTransaction;
  final void Function(int syncingHeight, int nodeHeight)? onSyncingUpdate;
  final void Function(Object? error, StackTrace stackTrace)? onError;

  Duration _pollingInterval;

  Timer? _timer;

  int _lastTxCount = -1;
  void _pollingLoop() {
    wallet.refreshTransactions().then((_) {
      final txCount = wallet.transactionCount();
      if (txCount > _lastTxCount) {
        onNewTransaction?.call();
      }
      _lastTxCount = txCount;
    });

    final currentSyncingHeight = wallet.getCurrentHeight();
    if (currentSyncingHeight < 0) {
      return; // todo: improve/check for errors?
    }

    final nodeHeight = wallet.getNodeHeight();
    if (currentSyncingHeight > nodeHeight) {
      return; // todo: improve/check for errors?
    }

    onSyncingUpdate?.call(currentSyncingHeight, nodeHeight);
  }

  /// Start polling the wallet.
  /// Additional calls to [start] will be ignored if it is already running.
  void start() {
    if (_timer == null) {
      _timer = Timer.periodic(_pollingInterval, (_) {
        try {
          _pollingLoop();
        } catch (error, stackTrace) {
          onError?.call(error, stackTrace);
        }
      });
    }
  }

  /// Change the polling interval.
  /// This will cancel any polling in progress and restart with the new [interval].
  void changePollingInterval(Duration interval) {
    stop();
    _pollingInterval = interval;
    start();
  }

  /// Stop polling.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
