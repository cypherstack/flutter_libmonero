import 'dart:async';
import 'dart:io';

import 'package:cw_core/account.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/monero_transaction_priority.dart';
import 'package:cw_core/monero_wallet_keys.dart';
import 'package:cw_core/monero_wallet_utils.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/utxo.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_wownero/api/structs/pending_transaction.dart';
import 'package:cw_wownero/api/wallet.dart';
import 'package:cw_wownero/api/wownero_output.dart';
import 'package:cw_wownero/pending_wownero_transaction.dart';
import 'package:cw_wownero/wownero_amount_format.dart';
import 'package:cw_wownero/wownero_balance.dart';
import 'package:cw_wownero/wownero_transaction_creation_credentials.dart';
import 'package:cw_wownero/wownero_transaction_creation_exception.dart';
import 'package:cw_wownero/wownero_transaction_history.dart';
import 'package:cw_wownero/wownero_transaction_info.dart';
import 'package:cw_wownero/wownero_wallet_addresses.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:monero/wownero.dart' as wownero;

part 'wownero_wallet.g.dart';

const wowneroBlockSize = 1000;

class WowneroWallet = WowneroWalletBase with _$WowneroWallet;

abstract class WowneroWalletBase extends WalletBase<WowneroBalance,
    WowneroTransactionHistory, WowneroTransactionInfo> with Store {
  WowneroWalletBase({
    required WalletInfo walletInfo,
    required this.wallet,
  }) : super(walletInfo) {
    transactionHistory = WowneroTransactionHistory();
    balance = ObservableMap<CryptoCurrency?, WowneroBalance>.of({
      CryptoCurrency.wow: WowneroBalance(
          fullBalance: wallet.getFullBalance(accountIndex: 0),
          unlockedBalance: wallet.getFullBalance(accountIndex: 0))
    });
    _isTransactionUpdating = false;
    _hasSyncAfterStartup = false;
    walletAddresses = WowneroWalletAddresses(walletInfo, wallet);
    _onAccountChangeReaction =
        reaction((_) => walletAddresses.account, (Account? account) {
      balance = ObservableMap<CryptoCurrency?,
          WowneroBalance>.of(<CryptoCurrency?, WowneroBalance>{
        currency: WowneroBalance(
            fullBalance: wallet.getFullBalance(accountIndex: account!.id),
            unlockedBalance:
                wallet.getUnlockedBalance(accountIndex: account.id))
      });
      walletAddresses.updateSubaddressList(accountIndex: account.id);
    });
  }

  static const int _autoSaveInterval = 30;

  wownero.Coins? _coinsPointer;

  final WOWWallet wallet;

  @override
  late WowneroWalletAddresses walletAddresses;

  @override
  @observable
  SyncStatus? syncStatus;

  @override
  @observable
  ObservableMap<CryptoCurrency?, WowneroBalance>? balance;

  @override
  String get seed => wallet.getSeed();

  @override
  MoneroWalletKeys get keys => MoneroWalletKeys(
        privateSpendKey: wallet.getSecretSpendKey(),
        privateViewKey: wallet.getSecretViewKey(),
        publicSpendKey: wallet.getPublicSpendKey(),
        publicViewKey: wallet.getPublicViewKey(),
      );

  ReactionDisposer? _onAccountChangeReaction;
  late bool _isTransactionUpdating;
  late bool _hasSyncAfterStartup;
  Timer? _autoSaveTimer;

  void Function({required int height, required int blocksLeft})? onNewBlock;
  void Function()? onNewTransaction;
  void Function()? syncStatusChanged;

  Future<void> init() async {
    await walletAddresses.init();
    balance = ObservableMap<CryptoCurrency?,
        WowneroBalance>.of(<CryptoCurrency?, WowneroBalance>{
      currency: WowneroBalance(
          fullBalance:
              wallet.getFullBalance(accountIndex: walletAddresses.account!.id),
          unlockedBalance: wallet.getUnlockedBalance(
              accountIndex: walletAddresses.account!.id))
    });
    _setListeners();
    await updateTransactions();

    if (walletInfo.isRecovery!) {
      wallet.setRecoveringFromSeed(isRecovery: walletInfo.isRecovery!);

      if (wallet.getCurrentHeight() <= 1) {
        wallet.setRefreshFromBlockHeight(height: walletInfo.restoreHeight ?? 0);
      }
    }

    // _autoSaveTimer = Timer.periodic(
    //     Duration(seconds: _autoSaveInterval), (_) async => await save());
  }

  @override
  void close() {
    wallet.stopListeners();
    _onAccountChangeReaction?.reaction.dispose();
    _autoSaveTimer?.cancel();
  }

  @override
  Future<void> connectToNode({
    required Node node,
    required String? socksProxyAddress,
  }) async {
    try {
      syncStatus = ConnectingSyncStatus();
      syncStatusChanged?.call();
      await wallet.setupNode(
        address: node.uri.toString(),
        login: node.login,
        password: node.password,
        useSSL: node.isSSL,
        isLightWallet: false, // FIXME: hardcoded value
        socksProxyAddress: socksProxyAddress,
      );

      await wallet.setTrustedDaemon(node.trusted);
      syncStatus = ConnectedSyncStatus();
      syncStatusChanged?.call();
    } catch (e, s) {
      syncStatus = FailedSyncStatus();
      syncStatusChanged?.call();
      if (kDebugMode) print("$e\n$s");
    }
  }

  @override
  Future<void> startSync() async {
    try {
      _setInitialHeight();
    } catch (_) {}

    try {
      syncStatus = StartingSyncStatus();
      wallet.startRefresh();
      _setListeners();
      wallet.startListeners();
      syncStatusChanged?.call();
    } catch (e, s) {
      syncStatus = FailedSyncStatus();
      syncStatusChanged?.call();
      if (kDebugMode) print("$runtimeType.startSync() error: $e\n$s");
      rethrow;
    }
  }

  bool validateAddress(String address) {
    return wownero.Wallet_addressValid(address, 0);
  }

  @override
  Future<PendingTransaction> createTransaction(
    Object credentials, {
    required List<UTXO>? inputs,
  }) async {
    final _credentials = credentials as WowneroTransactionCreationCredentials;
    final outputs = _credentials.outputs!;
    final hasMultiDestination = outputs.length > 1;
    final unlockedBalance =
        wallet.getUnlockedBalance(accountIndex: walletAddresses.account!.id);

    final PendingTransactionDescription pendingTransactionDescription;

    if (!(syncStatus is SyncedSyncStatus)) {
      throw WowneroTransactionCreationException('The wallet is not synced.');
    }

    if (inputs == null || inputs.isEmpty) {
      await updateUTXOs();
      inputs = utxos;
    }

    inputs.removeWhere((utxo) => utxo.isFrozen && !utxo.isUnlocked);

    if (inputs.isEmpty) {
      throw Exception("No usable inputs found!");
    }

    final inputStrings = inputs.map((e) => e.keyImage).toList();

    if (hasMultiDestination) {
      if (outputs
          .any((item) => item.sendAll! || item.formattedCryptoAmount! <= 0)) {
        throw WowneroTransactionCreationException(
            'Wrong balance. Not enough WOW on your balance.');
      }

      final int totalAmount =
          outputs.fold(0, (acc, value) => acc + value.formattedCryptoAmount!);

      if (unlockedBalance < totalAmount) {
        throw WowneroTransactionCreationException(
            'Wrong balance. Not enough WOW on your balance.');
      }

      final wowneroOutputs = outputs.map((output) {
        final outputAddress =
            output.isParsedAddress! ? output.extractedAddress : output.address;

        return WowneroOutput(
            address: outputAddress,
            amount: output.cryptoAmount!.replaceAll(',', '.'));
      }).toList();

      pendingTransactionDescription = await wallet.createTransactionMultDest(
        outputs: wowneroOutputs,
        priorityRaw: _credentials.priority!.serialize()!,
        accountIndex: walletAddresses.account!.id,
        preferredInputs: inputStrings,
      );
    } else {
      final output = outputs.first;
      final address =
          output.isParsedAddress! ? output.extractedAddress : output.address;
      final amount =
          output.sendAll! ? null : output.cryptoAmount!.replaceAll(',', '.');
      final formattedAmount =
          output.sendAll! ? null : output.formattedCryptoAmount;

      if ((formattedAmount != null && unlockedBalance < formattedAmount) ||
          (formattedAmount == null && unlockedBalance <= 0)) {
        final formattedBalance = wowneroAmountToString(amount: unlockedBalance);

        throw WowneroTransactionCreationException(
            'Incorrect unlocked balance. Unlocked: $formattedBalance. Transaction amount: ${output.cryptoAmount}.');
      }

      pendingTransactionDescription = await wallet.createTransaction(
        address: address!,
        amount: amount,
        priorityRaw: _credentials.priority!.serialize()!,
        accountIndex: walletAddresses.account!.id,
        preferredInputs: inputStrings,
      );
    }

    return PendingWowneroTransaction(pendingTransactionDescription, wallet);
  }

  @override
  int calculateEstimatedFee(TransactionPriority priority, int amount) {
    // FIXME: hardcoded value;

    if (priority is MoneroTransactionPriority) {
      switch (priority) {
        case MoneroTransactionPriority.slow:
          return 24590000;
        case MoneroTransactionPriority.regular:
          return 123050000;
        case MoneroTransactionPriority.medium:
          return 245029999;
        case MoneroTransactionPriority.fast:
          return 614530000;
        case MoneroTransactionPriority.fastest:
          return 26021600000;
      }
    }

    return 0;
  }

  @override
  Future<bool> save({bool prioritySave = false}) async {
    if (kDebugMode) print("save is called");
    await walletAddresses.updateAddressesInBox();
    if (!Platform.isWindows) {
      await backupWalletFiles(name: name!, type: WalletType.wownero);
    }
    await wallet.store();
    return true;
  }

  @override
  Future<void> changePassword(String password) async {
    wallet.setPasswordSync(password);
  }

  Future<int> getNodeHeight() async => wallet.getNodeHeight();

  int getSeedHeight(String seed) =>
      wownero.WOWNERO_deprecated_14WordSeedHeight(seed: seed);

  Future<bool> isConnected() async => wallet.isConnected();

  Future<void> setAsRecovered() async {
    walletInfo.isRecovery = false;
    await walletInfo.save();
  }

  @override
  Future<void> rescan({int? height}) async {
    walletInfo.restoreHeight = height;
    walletInfo.isRecovery = true;
    wallet.setRefreshFromBlockHeight(height: height ?? 0);
    wallet.rescanBlockchainAsync();
    await startSync();
    _askForUpdateBalance();
    walletAddresses.accountList.update();
    await _askForUpdateTransactionHistory();
    await save();
    await walletInfo.save();
  }

  String getTransactionAddress(int accountIndex, int addressIndex) =>
      wallet.getAddress(accountIndex: accountIndex, addressIndex: addressIndex);

  @override
  Future<Map<String, WowneroTransactionInfo>> fetchTransactions() async {
    wallet.refreshTransactions();
    return _getAllTransactions(null).fold<Map<String, WowneroTransactionInfo>>(
        <String, WowneroTransactionInfo>{},
        (Map<String, WowneroTransactionInfo> acc, WowneroTransactionInfo tx) {
      acc[tx.id] = tx;
      acc[tx.id]!.additionalInfo ??= {};
      acc[tx.id]!.additionalInfo!["accountIndex"] = tx.accountIndex;
      acc[tx.id]!.additionalInfo!["addressIndex"] = tx.addressIndex;
      return acc;
    });
  }

  Future<void> updateTransactions() async {
    try {
      if (_isTransactionUpdating) {
        return;
      }

      _isTransactionUpdating = true;
      final transactions = await fetchTransactions();
      transactionHistory!.addMany(transactions);
      await transactionHistory!.save();
      _isTransactionUpdating = false;
    } catch (e) {
      if (kDebugMode) print(e);
      _isTransactionUpdating = false;
    }
  }

  String getSubaddressLabel(int accountIndex, int addressIndex) {
    return wallet.getSubaddressLabel(accountIndex, addressIndex);
  }

  void _refreshCoins() {
    _coinsPointer = wownero.Wallet_coins(wallet.wptr);
    wownero.Coins_refresh(_coinsPointer!);
  }

  @override
  Future<void> freeze(String keyImage) async {
    if (keyImage.isEmpty) {
      throw Exception("Attempted freeze of empty keyImage.");
    }

    final count = wownero.Coins_getAll_size(_coinsPointer!);

    for (int i = 0; i < count; i++) {
      if (keyImage ==
          wownero.CoinsInfo_keyImage(wownero.Coins_coin(_coinsPointer!, i))) {
        wownero.Coins_setFrozen(_coinsPointer!, index: i);
        return;
      }
    }

    throw Exception(
      "Can't freeze utxo for the gen keyImage if it cannot be found. *points at temple*",
    );
  }

  @override
  Future<void> thaw(String keyImage) async {
    if (keyImage.isEmpty) {
      throw Exception("Attempted thaw of empty keyImage.");
    }

    final count = wownero.Coins_getAll_size(_coinsPointer!);

    for (int i = 0; i < count; i++) {
      if (keyImage ==
          wownero.CoinsInfo_keyImage(wownero.Coins_coin(_coinsPointer!, i))) {
        wownero.Coins_thaw(_coinsPointer!, index: i);
        return;
      }
    }

    throw Exception(
      "Can't thaw utxo for the gen keyImage if it cannot be found. *points at temple*",
    );
  }

  @override
  Future<void> updateUTXOs() async {
    try {
      utxos.clear();

      _refreshCoins();
      final count = wownero.Coins_getAll_size(_coinsPointer!);

      if (kDebugMode) {
        print("wownero::found_utxo_count=$count");
      }

      for (int i = 0; i < count; i++) {
        final coinPointer = wownero.Coins_coin(_coinsPointer!, i);

        // if (!wownero.CoinsInfo_spent(coinPointer)) {
        final hash = wownero.CoinsInfo_hash(coinPointer);

        if (hash.isNotEmpty) {
          final unspent = UTXO(
            address: wownero.CoinsInfo_address(coinPointer),
            hash: hash,
            keyImage: wownero.CoinsInfo_keyImage(coinPointer),
            value: wownero.CoinsInfo_amount(coinPointer),
            isFrozen: wownero.CoinsInfo_frozen(coinPointer),
            isUnlocked: wownero.CoinsInfo_unlocked(coinPointer),
            vout: wownero.CoinsInfo_internalOutputIndex(coinPointer),
            spent: wownero.CoinsInfo_spent(coinPointer),
            height: wownero.CoinsInfo_blockHeight(coinPointer),
            coinbase: wownero.CoinsInfo_coinbase(coinPointer),
          );

          utxos.add(unspent);
        } else {
          if (kDebugMode) {
            print("Found empty hash in wownero utxo?!");
          }
        }
        // }
      }
      _askForUpdateBalance();
    } catch (e, s) {
      if (kDebugMode) {
        print("$e\n$s");
      }
    }
  }

  List<WowneroTransactionInfo> _getAllTransactions(dynamic _) => wallet
      .getAllTransactions()
      .map((row) => WowneroTransactionInfo(
          row.hash,
          row.blockheight,
          row.isSpend
              ? TransactionDirection.outgoing
              : TransactionDirection.incoming,
          row.timeStamp,
          row.isPending,
          row.amount,
          row.accountIndex,
          row.addressIndex,
          row.fee))
      .toList();
  // wownero_transaction_history
  //     .getAllTransations()
  //     .map((row) => WowneroTransactionInfo.fromRow(row))
  //     .toList();

  void _setListeners() {
    wallet.stopListeners();
    wallet.onNewTransaction = _onNewTransaction;
    wallet.onNewBlock = _onNewBlock;
  }

  void _setInitialHeight() {
    if (walletInfo.isRecovery!) {
      return;
    }

    final currentHeight = wallet.getCurrentHeight();

    if (currentHeight <= 1) {
      final height = _getHeightByDate(walletInfo.date);
      wallet.setRecoveringFromSeed(isRecovery: true);
      wallet.setRefreshFromBlockHeight(height: height);
    }
  }

  int _getHeightDistance(DateTime date) {
    final distance =
        DateTime.now().millisecondsSinceEpoch - date.millisecondsSinceEpoch;
    final distanceSec = distance / 1000;
    final daysTmp = (distanceSec / 86400).round();
    final days = daysTmp < 1 ? 1 : daysTmp;

    return days * 2000;
  }

  int _getHeightByDate(DateTime date) {
    final nodeHeight = wallet.getNodeHeightSync();
    final heightDistance = _getHeightDistance(date);

    if (nodeHeight <= 0) {
      return 0;
    }

    return nodeHeight - heightDistance;
  }

  void _askForUpdateBalance() {
    final unlockedBalance = _getUnlockedBalance();
    final fullBalance = _getFullBalance();

    if (balance![currency]!.fullBalance != fullBalance ||
        balance![currency]!.unlockedBalance != unlockedBalance) {
      balance![currency] = WowneroBalance(
          fullBalance: fullBalance, unlockedBalance: unlockedBalance);
    }
  }

  Future<void> _askForUpdateTransactionHistory() async =>
      await updateTransactions();

  int _getFullBalance() =>
      wallet.getFullBalance(accountIndex: walletAddresses.account!.id);

  int _getUnlockedBalance() =>
      wallet.getUnlockedBalance(accountIndex: walletAddresses.account!.id);

  void _onNewBlock(int height, int blocksLeft, double ptc) async {
    try {
      if (walletInfo.isRecovery!) {
        await _askForUpdateTransactionHistory();
        _askForUpdateBalance();
        walletAddresses.accountList.update();
      }

      if (blocksLeft < 100) {
        await _askForUpdateTransactionHistory();
        _askForUpdateBalance();
        walletAddresses.accountList.update();
        syncStatus = SyncedSyncStatus();
        syncStatusChanged?.call();

        if (!_hasSyncAfterStartup) {
          _hasSyncAfterStartup = true;
          await save();
        }

        if (walletInfo.isRecovery!) {
          await setAsRecovered();
        }
      } else {
        syncStatus = SyncingSyncStatus(blocksLeft, ptc, height);
        syncStatusChanged?.call();
      }
    } catch (e) {
      if (kDebugMode) print(e.toString());
    }
    onNewBlock?.call(height: height, blocksLeft: blocksLeft);
  }

  void _onNewTransaction() async {
    try {
      await _askForUpdateTransactionHistory();
      _askForUpdateBalance();
      await Future<void>.delayed(Duration(seconds: 1));
    } catch (e) {
      if (kDebugMode) print(e.toString());
    }
    onNewTransaction?.call();
  }
}
