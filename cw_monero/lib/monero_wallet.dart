import 'dart:async';
import 'dart:io';

import 'package:cw_core/account.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/monero_amount_format.dart';
import 'package:cw_core/monero_balance.dart';
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
import 'package:cw_monero/api/monero_output.dart';
import 'package:cw_monero/api/structs/pending_transaction.dart';
import 'package:cw_monero/api/wallet.dart';
import 'package:cw_monero/monero_transaction_creation_credentials.dart';
import 'package:cw_monero/monero_transaction_creation_exception.dart';
import 'package:cw_monero/monero_transaction_history.dart';
import 'package:cw_monero/monero_transaction_info.dart';
import 'package:cw_monero/monero_wallet_addresses.dart';
import 'package:cw_monero/pending_monero_transaction.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:monero/monero.dart' as monero;

part 'monero_wallet.g.dart';

const moneroBlockSize = 1000;

class MoneroWallet = MoneroWalletBase with _$MoneroWallet;

abstract class MoneroWalletBase extends WalletBase<MoneroBalance,
    MoneroTransactionHistory, MoneroTransactionInfo> with Store {
  MoneroWalletBase({
    required WalletInfo walletInfo,
    required this.wallet,
  }) : super(walletInfo) {
    transactionHistory = MoneroTransactionHistory();
    balance = ObservableMap<CryptoCurrency, MoneroBalance>.of({
      CryptoCurrency.xmr: MoneroBalance(
          fullBalance: wallet.getFullBalance(accountIndex: 0),
          unlockedBalance: wallet.getFullBalance(accountIndex: 0))
    });
    _isTransactionUpdating = false;
    _hasSyncAfterStartup = false;
    walletAddresses = MoneroWalletAddresses(walletInfo, wallet);
    _onAccountChangeReaction =
        reaction((_) => walletAddresses.account, (Account? account) {
      balance = ObservableMap<CryptoCurrency?,
          MoneroBalance>.of(<CryptoCurrency?, MoneroBalance>{
        currency: MoneroBalance(
            fullBalance: wallet.getFullBalance(accountIndex: account!.id),
            unlockedBalance:
                wallet.getUnlockedBalance(accountIndex: account.id))
      });
      walletAddresses.updateSubaddressList(accountIndex: account.id);
    });
  }

  static const int _autoSaveInterval = 63;

  monero.Coins? _coinsPointer;

  final XMRWallet wallet;

  @override
  late MoneroWalletAddresses walletAddresses;

  @override
  @observable
  SyncStatus? syncStatus;

  @override
  @observable
  ObservableMap<CryptoCurrency?, MoneroBalance>? balance;

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
    balance = ObservableMap<CryptoCurrency?, MoneroBalance>.of(<CryptoCurrency?,
        MoneroBalance>{
      currency: MoneroBalance(
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

  @override
  Future<PendingTransaction> createTransaction(
    Object credentials, {
    required List<UTXO>? inputs,
  }) async {
    final _credentials = credentials as MoneroTransactionCreationCredentials;
    final outputs = _credentials.outputs!;
    final hasMultiDestination = outputs.length > 1;
    final unlockedBalance =
        wallet.getUnlockedBalance(accountIndex: walletAddresses.account!.id);

    final PendingTransactionDescription pendingTransactionDescription;

    if (!(syncStatus is SyncedSyncStatus)) {
      throw MoneroTransactionCreationException('The wallet is not synced.');
    }

    if (inputs == null || inputs.isEmpty) {
      await updateUTXOs();
      inputs = utxos;
    }

    inputs.removeWhere((utxo) => utxo.isFrozen && !utxo.isUnlocked);

    if (inputs.isEmpty) {
      throw Exception("No usable inputs found!");
    }

    print("INPUTS TO USE: $inputs");

    final inputStrings = inputs.map((e) => e.keyImage).toList();

    if (hasMultiDestination) {
      if (outputs
          .any((item) => item.sendAll! || item.formattedCryptoAmount! <= 0)) {
        throw MoneroTransactionCreationException(
            'Wrong balance. Not enough XMR on your balance.');
      }

      final int totalAmount =
          outputs.fold(0, (acc, value) => acc + value.formattedCryptoAmount!);

      if (unlockedBalance < totalAmount) {
        throw MoneroTransactionCreationException(
            'Wrong balance. Not enough XMR on your balance.');
      }

      final moneroOutputs = outputs.map((output) {
        final outputAddress =
            output.isParsedAddress! ? output.extractedAddress : output.address;

        return MoneroOutput(
            address: outputAddress,
            amount: output.cryptoAmount!.replaceAll(',', '.'));
      }).toList();

      pendingTransactionDescription = await wallet.createTransactionMultDest(
        outputs: moneroOutputs,
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
        final formattedBalance = moneroAmountToString(amount: unlockedBalance);

        throw MoneroTransactionCreationException(
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

    return PendingMoneroTransaction(pendingTransactionDescription, wallet);
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
      await backupWalletFiles(name: name!, type: WalletType.monero);
    }
    await wallet.store();
    return true;
  }

  @override
  Future<void> changePassword(String password) async {
    wallet.setPasswordSync(password);
  }

  Future<int> getNodeHeight() async => wallet.getNodeHeight();

  Future<bool> isConnected() async => wallet.isConnected();

  Future<void> setAsRecovered() async {
    walletInfo.isRecovery = false;
    await walletInfo.save();
  }

  @override
  Future<void> rescan({int? height}) async {
    walletInfo.restoreHeight = height;
    walletInfo.isRecovery = true;
    if (height != null) {
      wallet.setRefreshFromBlockHeight(height: height);
    }
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
  Future<Map<String, MoneroTransactionInfo>> fetchTransactions() async {
    wallet.refreshTransactions();
    return _getAllTransactions(null).fold<Map<String, MoneroTransactionInfo>>(
        <String, MoneroTransactionInfo>{},
        (Map<String, MoneroTransactionInfo> acc, MoneroTransactionInfo tx) {
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

  bool validateAddress(String address) {
    return monero.Wallet_addressValid(address, 0);
  }

  void _refreshCoins() {
    _coinsPointer = monero.Wallet_coins(wallet.wptr);
    monero.Coins_refresh(_coinsPointer!);
  }

  @override
  Future<void> updateUTXOs() async {
    try {
      utxos.clear();

      _refreshCoins();
      final count = monero.Coins_getAll_size(_coinsPointer!);

      if (kDebugMode) {
        print("monero::found_utxo_count=$count");
      }

      for (int i = 0; i < count; i++) {
        final coinPointer = monero.Coins_coin(_coinsPointer!, i);

        final hash = monero.CoinsInfo_hash(coinPointer);

        if (hash.isNotEmpty) {
          final unspent = UTXO(
            address: monero.CoinsInfo_address(coinPointer),
            hash: hash,
            keyImage: monero.CoinsInfo_keyImage(coinPointer),
            value: monero.CoinsInfo_amount(coinPointer),
            isFrozen: monero.CoinsInfo_frozen(coinPointer),
            isUnlocked: monero.CoinsInfo_unlocked(coinPointer),
            vout: monero.CoinsInfo_internalOutputIndex(coinPointer),
            spent: monero.CoinsInfo_spent(coinPointer),
            height: monero.CoinsInfo_blockHeight(coinPointer),
            coinbase: monero.CoinsInfo_coinbase(coinPointer),
          );

          utxos.add(unspent);
        } else {
          if (kDebugMode) {
            print("Found empty hash in monero utxo?!");
          }
        }
      }
      _askForUpdateBalance();
    } catch (e, s) {
      if (kDebugMode) {
        print("$e\n$s");
      }
    }
  }

  List<MoneroTransactionInfo> _getAllTransactions(dynamic _) =>
      wallet.getAllTransactions().map((row) {
        return MoneroTransactionInfo(
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
          row.fee,
        );
      }).toList();
  // .map((row) => MoneroTransactionInfo.fromRow(row))
  // .toList();

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
    final daysTmp = (distance / 86400).round();
    final days = daysTmp < 1 ? 1 : daysTmp;

    return days * 1000;
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
      balance![currency] = MoneroBalance(
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
