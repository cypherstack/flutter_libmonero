import 'dart:async';

import '../logging.dart';
import '../models/wallet_listener.dart';
import '../wallet.dart';

mixin Polling on Wallet {
  final List<WalletListener> _listeners = [];

  void addListener(WalletListener listener) {
    _listeners.add(listener);
  }

  void removeListener(WalletListener listener) {
    _listeners.remove(listener);
  }

  List<WalletListener> getListeners() => List.unmodifiable(_listeners);

  Timer? _pollingTimer;
  Duration pollingInterval = const Duration(seconds: 5);

  /// Start polling the wallet.
  /// Additional calls to [startListeners] will be ignored if it is already running.
  void startListeners() {
    if (_pollingTimer == null) {
      _pollingTimer = Timer.periodic(pollingInterval, (_) {
        try {
          _pollingLoop();
        } catch (error, stackTrace) {
          for (final listener in getListeners()) {
            listener.onError?.call(error, stackTrace);
          }
        }
      });
    }
  }

  void stopListeners() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  int? _lastDaemonHeight;
  int? _lastSyncHeight;
  int? _lastBalanceUnlocked;
  int? _lastBalanceFull;

  void _pollingLoop() {
    // _cwListenerPointer ??= monero.MONERO_cw_getWalletListener(_getWalletPointer(),);
    // final needsRefresh = monero.MONERO_cw_WalletListener_isNeedToRefresh(_cwListenerPointer,);
    // monero.MONERO_cw_WalletListener_resetNeedToRefresh(_cwListenerPointer,);
    // if (needsRefresh && !_isSyncing) {
    //   sync().then((value) {
    //
    //     refreshTransactions();
    //     refreshCoins();
    //     });
    // }

    Logging.log?.d("Polling");

    final full = getBalance();
    final unlocked = getUnlockedBalance();
    if (unlocked != _lastBalanceUnlocked || full != _lastBalanceFull) {
      Logging.log?.d("listener.onBalancesChanged");
      for (final listener in getListeners()) {
        listener.onBalancesChanged
            ?.call(newBalance: full, newUnlockedBalance: unlocked);
      }
    }
    _lastBalanceUnlocked = unlocked;
    _lastBalanceFull = full;

    final nodeHeight = getDaemonHeight();
    final heightChanged = nodeHeight != _lastDaemonHeight;
    if (heightChanged) {
      Logging.log?.d("listener.onNewBlock");
      for (final listener in getListeners()) {
        listener.onNewBlock?.call(nodeHeight);
      }
    }
    _lastDaemonHeight = nodeHeight;

    final currentSyncingHeight = syncHeight();
    if (currentSyncingHeight >= 0 &&
        currentSyncingHeight <= nodeHeight &&
        (heightChanged || currentSyncingHeight != _lastSyncHeight)) {
      Logging.log?.d("listener.onSyncingUpdate");
      for (final listener in getListeners()) {
        listener.onSyncingUpdate?.call(
          syncHeight: currentSyncingHeight,
          nodeHeight: nodeHeight,
        );
      }
    }

    _lastSyncHeight = currentSyncingHeight;
  }
}
