import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:monero/src/generated_bindings_wownero.g.dart' as wownero_gen;
import 'package:monero/wownero.dart' as wownero;

import 'enums/transaction_priority.dart';
import 'enums/wownero_seed_type.dart';
import 'exceptions/creation_transaction_exception.dart';
import 'exceptions/setup_wallet_exception.dart';
import 'exceptions/wallet_creation_exception.dart';
import 'exceptions/wallet_opening_exception.dart';
import 'exceptions/wallet_restore_from_keys_exception.dart';
import 'exceptions/wallet_restore_from_seed_exception.dart';
import 'models/output.dart';
import 'models/transaction.dart';
import 'models/utxo.dart';
import 'structs/pending_transaction.dart';
import 'wallet.dart';

class WowneroWallet implements Wallet {
  // internal constructor
  WowneroWallet._(wownero.wallet pointer, String path)
      : _walletPointer = pointer,
        _path = path;
  final String _path;

  // shared pointer
  static wownero.WalletManager? __wmPtr;
  static final wownero.WalletManager _wmPtr = Pointer.fromAddress((() {
    try {
      wownero.printStarts = true;
      __wmPtr ??= wownero.WalletManagerFactory_getWalletManager();
      if (kDebugMode) print("ptr: $__wmPtr");
    } catch (e) {
      if (kDebugMode) print(e);
    }
    return __wmPtr!.address;
  })());

  // internal map of wallets
  static final Map<String, WowneroWallet> _openedWalletsByPath = {};

  // instance pointers
  wownero.Coins? _coinsPointer;
  wownero.TransactionHistory? _transactionHistoryPointer;
  wownero.wallet? _walletPointer;
  wownero.wallet _getWalletPointer() {
    if (_walletPointer == null) {
      throw Exception(
        "WowneroWallet was closed!",
      );
    }
    return _walletPointer!;
  }

  // special check to see if wallet exists
  static bool isWalletExist(String path) =>
      wownero.WalletManager_walletExists(_wmPtr, path);

  // static factory constructor functions

  static Future<WowneroWallet> createWallet({
    required String path,
    required String password,
    String language = "English",
    required WowneroSeedType seedType,
    int networkType = 0,
    bool overrideDeprecated14WordSeedException = false,
  }) async {
    final Pointer<Void> walletPointer;

    switch (seedType) {
      case WowneroSeedType.fourteen:
        if (!overrideDeprecated14WordSeedException) {
          throw Exception(
            "New 14 word seed wallet creation is deprecated. "
            "If you really need this, "
            "set overrideDeprecated14WordSeedException to true.",
          );
        }

        walletPointer = wownero.WOWNERO_deprecated_create14WordSeed(
          path: path,
          password: password,
          language: language,
          networkType: networkType,
        );
        break;

      case WowneroSeedType.sixteen:
        final seed = wownero.Wallet_createPolyseed(language: language);
        walletPointer = wownero.WalletManager_createWalletFromPolyseed(
          _wmPtr,
          path: path,
          password: password,
          mnemonic: seed,
          seedOffset: '',
          newWallet: true,
          restoreHeight: 0,
          kdfRounds: 1,
          networkType: networkType,
        );
        break;

      case WowneroSeedType.twentyFive:
        walletPointer = wownero.WalletManager_createWallet(
          _wmPtr,
          path: path,
          password: password,
          language: language,
          networkType: networkType,
        );
        break;
    }

    final status = wownero.Wallet_status(walletPointer);
    if (status != 0) {
      throw WalletCreationException(
          message: wownero.Wallet_errorString(walletPointer));
    }

    final address = walletPointer.address;
    await Isolate.run(() {
      wownero.Wallet_store(Pointer.fromAddress(address), path: path);
    });

    final wallet = WowneroWallet._(walletPointer, path);
    _openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static Future<WowneroWallet> restoreWalletFromSeed({
    required String path,
    required String password,
    required String seed,
    int networkType = 0,
    int restoreHeight = 0,
  }) async {
    final wownero.wallet walletPointer;
    final seedLength = seed.split(' ').length;
    if (seedLength == 25) {
      walletPointer = wownero.WalletManager_recoveryWallet(
        _wmPtr,
        path: path,
        password: password,
        mnemonic: seed,
        restoreHeight: restoreHeight,
        seedOffset: '',
        networkType: 0,
      );
    } else if (seedLength == 16) {
      walletPointer = wownero.WalletManager_createWalletFromPolyseed(
        _wmPtr,
        path: path,
        password: password,
        mnemonic: seed,
        seedOffset: '',
        newWallet: false,
        restoreHeight: restoreHeight,
        kdfRounds: 1,
      );
    } else if (seedLength == 14) {
      walletPointer = wownero.WOWNERO_deprecated_restore14WordSeed(
        path: path,
        password: password,
        language: seed, // yes the "language" param is misnamed
        networkType: networkType,
      );
      restoreHeight =
          wownero.Wallet_getRefreshFromBlockHeight(walletPointer);
 
    } else {
      throw Exception("Bad seed length: $seedLength");
    }

    final status = wownero.Wallet_status(walletPointer);

    if (status != 0) {
      final error = wownero.Wallet_errorString(walletPointer);
      throw WalletRestoreFromSeedException(message: error);
    }

    final address = walletPointer.address;
    await Isolate.run(() {
      wownero.Wallet_store(Pointer.fromAddress(address), path: path);
    });

    final wallet = WowneroWallet._(walletPointer, path);
    _openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static WowneroWallet restoreWalletFromKeys({
    required String path,
    required String password,
    required String language,
    required String address,
    required String viewKey,
    required String spendKey,
    int networkType = 0,
    int restoreHeight = 0,
  }) {
    final walletPointer = wownero.WalletManager_createWalletFromKeys(
      _wmPtr,
      path: path,
      password: password,
      restoreHeight: restoreHeight,
      addressString: address,
      viewKeyString: viewKey,
      spendKeyString: spendKey,
      nettype: 0,
    );

    final status = wownero.Wallet_status(walletPointer);
    if (status != 0) {
      throw WalletRestoreFromKeysException(
        message: wownero.Wallet_errorString(walletPointer),
      );
    }

    final wallet = WowneroWallet._(walletPointer, path);
    _openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static WowneroWallet restoreWalletFromSpendKey({
    required String path,
    required String password,
    // required String seed,
    required String language,
    required String spendKey,
    int networkType = 0,
    int restoreHeight = 0,
  }) {
    final walletPointer =
        wownero.WalletManager_createDeterministicWalletFromSpendKey(
      _wmPtr,
      path: path,
      password: password,
      language: language,
      spendKeyString: spendKey,
      newWallet: true, // TODO(mrcyjanek): safe to remove
      restoreHeight: restoreHeight,
    );

    final status = wownero.Wallet_status(walletPointer);

    if (status != 0) {
      final err = wownero.Wallet_errorString(walletPointer);
      if (kDebugMode) print("err: $err");
      throw WalletRestoreFromKeysException(message: err);
    }

    // wownero.Wallet_setCacheAttribute(
    //   walletPointer,
    //   key: "cakewallet.seed",
    //   value: seed,
    // );
    final wallet = WowneroWallet._(walletPointer, path);
    wallet.store();
    _openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static WowneroWallet loadWallet({
    required String path,
    required String password,
    int networkType = 0,
  }) {
    WowneroWallet? wallet = _openedWalletsByPath[path];
    if (wallet != null) {
      return wallet;
    }

    try {
      final walletPointer = wownero.WalletManager_openWallet(_wmPtr,
          path: path, password: password);
      wallet = WowneroWallet._(walletPointer, path);
      _openedWalletsByPath[path] = wallet;
    } catch (e, s) {
      if (kDebugMode) print("$e\n$s");
      rethrow;
    }

    final status = wownero.Wallet_status(wallet._getWalletPointer());
    if (status != 0) {
      final err = wownero.Wallet_errorString(wallet._getWalletPointer());
      if (kDebugMode) print("status: " + err);
      throw WalletOpeningException(message: err);
    }
    return wallet;
  }

  // ===========================================================================

  @override
  int getRefreshFromBlockHeight() =>
      wownero.Wallet_getRefreshFromBlockHeight(_getWalletPointer());

  @override
  Future<bool> initConnection({
    required String daemonAddress,
    required bool trusted,
    String? daemonUsername,
    String? daemonPassword,
    bool useSSL = false,
    bool isLightWallet = false,
    String? socksProxyAddress,
  }) async {
    if (kDebugMode)
      print("init (initConnection()) node address: $daemonAddress");
    final pointerAddress = _getWalletPointer().address;
    await Isolate.run(() {
      wownero.Wallet_init(
        Pointer.fromAddress(pointerAddress),
        daemonAddress: daemonAddress,
        daemonUsername: daemonUsername ?? '',
        daemonPassword: daemonPassword ?? '',
        proxyAddress: socksProxyAddress ?? '',
        useSsl: useSSL,
        lightWallet: isLightWallet,
      );
    });
    final status = wownero.Wallet_status(_getWalletPointer());
    if (status != 0) {
      final err = wownero.Wallet_errorString(_getWalletPointer());
      if (kDebugMode) print("init (initConnection()) status: $status");
      if (kDebugMode) print("init (initConnection()) error: $err");
      throw SetupWalletException(message: err);
    }

    // TODO error handling?
    wownero.Wallet_setTrustedDaemon(
      _getWalletPointer(),
      arg: trusted,
    );

    return status == 0;
  }

  // this probably does not do what you think it does
  @override
  Future<bool> createWatchOnly({
    required String path,
    required String password,
    String language = "English",
  }) async {
    return await Isolate.run(
      () => wownero.Wallet_createWatchOnly(
        _getWalletPointer(),
        path: path,
        password: password,
        language: language,
      ),
    );
  }

  @override
  void close() {
    final pointerAddress = _getWalletPointer().address;
    wownero.Wallet_stop(Pointer.fromAddress(pointerAddress));
    // _walletPointer = null;
    // _openedWalletsByPath.remove(_path);
  }

  @override
  int getHeightByDate(DateTime date) {
    final nodeHeight = getNodeHeight();
    final heightDistance = Wallet.getHeightDistance(date);

    if (nodeHeight <= 0) {
      return 0;
    }

    return nodeHeight - heightDistance;
  }

  @override
  Future<void> store() async {
    final pointerAddress = _getWalletPointer().address;
    await Isolate.run(() {
      wownero.Wallet_store(Pointer.fromAddress(pointerAddress));
    });
  }

  @override
  void setPassword(String password) {
    wownero.Wallet_setPassword(_getWalletPointer(), password: password);
    final status = wownero.Wallet_status(_getWalletPointer());
    if (status == 0) {
      throw Exception(wownero.Wallet_errorString(_getWalletPointer()));
    }
  }

  @override
  String getSecretViewKey() =>
      wownero.Wallet_secretViewKey(_getWalletPointer());
  @override
  String getPublicViewKey() =>
      wownero.Wallet_publicViewKey(_getWalletPointer());
  @override
  String getSecretSpendKey() =>
      wownero.Wallet_secretSpendKey(_getWalletPointer());
  @override
  String getPublicSpendKey() =>
      wownero.Wallet_publicSpendKey(_getWalletPointer());
  @override
  String getSeed() {
    // final cakePolySeed = wownero.Wallet_getCacheAttribute(_getWalletPointer(),
    //     key: "cakewallet.seed");
    // if (cakePolySeed != "") {
    //   return cakePolySeed;
    // }
    final polySeed =
        wownero.Wallet_getPolyseed(_getWalletPointer(), passphrase: '');
    if (polySeed != "") {
      return polySeed;
    }
    final legacy = wownero.Wallet_seed(_getWalletPointer(), seedOffset: '');
    return legacy;
  }

  @override
  String getAddress({int accountIndex = 0, int addressIndex = 0}) =>
      wownero.Wallet_address(
        _getWalletPointer(),
        accountIndex: accountIndex,
        addressIndex: addressIndex,
      );

  @override
  int getFullBalance({int accountIndex = 0}) => wownero.Wallet_balance(
        _getWalletPointer(),
        accountIndex: accountIndex,
      );

  @override
  int getUnlockedBalance({int accountIndex = 0}) =>
      wownero.Wallet_unlockedBalance(
        _getWalletPointer(),
        accountIndex: accountIndex,
      );

  @override
  int getCurrentHeight() =>
      wownero.Wallet_blockChainHeight(_getWalletPointer());
  @override
  int getNodeHeight() =>
      wownero.Wallet_daemonBlockChainHeight(_getWalletPointer());

  @override
  void startRefreshAsync() {
    wownero.Wallet_refreshAsync(_getWalletPointer());
    wownero.Wallet_startRefresh(_getWalletPointer());
  }

  @override
  void setRecoveringFromSeed({required bool isRecovery}) =>
      wownero.Wallet_setRecoveringFromSeed(
        _getWalletPointer(),
        recoveringFromSeed: isRecovery,
      );

  @override
  void startRescan(DateTime? fromDate, int? blockHeightOverride) {
    final height = blockHeightOverride != null ? blockHeightOverride! : fromDate == null ? null : getHeightByDate(fromDate);
    if (height != null) {
      wownero.Wallet_setRefreshFromBlockHeight(
        _getWalletPointer(),
        refresh_from_block_height: height,
      );
    }
    wownero.Wallet_rescanBlockchainAsync(_getWalletPointer());
    startRefreshAsync(); // TODO: check we should keep this?
  }

  void _refreshCoins(int pointerAddress) =>
      wownero.Coins_refresh(Pointer.fromAddress(pointerAddress));
  @override
  Future<void> refreshCoins() async {
    _coinsPointer = wownero.Wallet_coins(_getWalletPointer());
    final pointerAddress = _coinsPointer!.address;
    await compute(_refreshCoins, pointerAddress);
  }

  @override
  Future<void> freezeCoin(String keyImage) async {
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
  Future<void> thawCoin(String keyImage) async {
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
  Future<List<UTXO>> getUTXOs({bool includeSpent = false}) async {
    try {
      await refreshCoins();
      final count = wownero.Coins_getAll_size(_coinsPointer!);

      if (kDebugMode) {
        print("monero::found_utxo_count=$count");
      }

      final List<UTXO> result = [];

      for (int i = 0; i < count; i++) {
        final coinPointer = wownero.Coins_coin(_coinsPointer!, i);

        final hash = wownero.CoinsInfo_hash(coinPointer);

        if (hash.isNotEmpty) {
          final spent = wownero.CoinsInfo_spent(coinPointer);

          if (includeSpent || !spent) {
            final utxo = UTXO(
              address: wownero.CoinsInfo_address(coinPointer),
              hash: hash,
              keyImage: wownero.CoinsInfo_keyImage(coinPointer),
              value: wownero.CoinsInfo_amount(coinPointer),
              isFrozen: wownero.CoinsInfo_frozen(coinPointer),
              isUnlocked: wownero.CoinsInfo_unlocked(coinPointer),
              vout: wownero.CoinsInfo_internalOutputIndex(coinPointer),
              spent: spent,
              height: wownero.CoinsInfo_blockHeight(coinPointer),
              coinbase: wownero.CoinsInfo_coinbase(coinPointer),
            );

            result.add(utxo);
          }
        } else {
          if (kDebugMode) {
            print("Found empty hash in monero utxo?!");
          }
        }
      }

      return result;
    } catch (e, s) {
      if (kDebugMode) {
        print("$e\n$s");
      }
      rethrow;
    }
  }

  @override
  String getTxKey(String txId) {
    return wownero.Wallet_getTxKey(_getWalletPointer(), txid: txId);
  }

  void _refreshTransactions(int pointerAddress) =>
      wownero.TransactionHistory_refresh(
        Pointer.fromAddress(
          pointerAddress,
        ),
      );
  @override
  Future<void> refreshTransactions() async {
    _transactionHistoryPointer = wownero.Wallet_history(_getWalletPointer());
    final pointerAddress = _transactionHistoryPointer!.address;
    await compute(_refreshTransactions, pointerAddress);
  }

  @override
  int transactionCount() =>
      wownero.TransactionHistory_count(_transactionHistoryPointer!);

  @override
  List<Transaction> getAllTransactions() {
    final size = transactionCount();

    return List.generate(
      size,
      (index) => Transaction(
        txInfo: wownero.TransactionHistory_transaction(
          _transactionHistoryPointer!,
          index: index,
        ),
        getTxKey: getTxKey,
      ),
    );
  }

  @override
  Transaction getTransaction(String txId) {
    return Transaction(
      txInfo: wownero.TransactionHistory_transactionById(
        _transactionHistoryPointer!,
        txid: txId,
      ),
      getTxKey: getTxKey,
    );
  }

  @override
  Future<int> estimateFee(TransactionPriority priority, int amount) async {
    // FIXME: hardcoded value;
    // TODO: This is likely wrong for wownero
    switch (priority) {
      case TransactionPriority.normal:
        return 24590000;
      case TransactionPriority.low:
        return 123050000;
      case TransactionPriority.medium:
        return 245029999;
      case TransactionPriority.high:
        return 614530000;
      case TransactionPriority.last:
        return 26021600000;
    }
  }

  @override
  Future<bool> isConnected() async {
    // if (isRefreshPending) return connected;
    // isRefreshPending = true;
    final address = _getWalletPointer().address;
    final result = await Isolate.run(() {
      return wownero.Wallet_connected(Pointer.fromAddress(address));
    });

    // connected = result == 1;
    // isRefreshPending = false;
    //
    // return connected;

    return result == 1;
  }

  // TODO check variance between this and createTransactionMultDest below
  @override
  Future<PendingTransactionDescription> createTransaction({
    required String address,
    required String paymentId,
    required TransactionPriority priority,
    String? amount,
    int accountIndex = 0,
    required List<String> preferredInputs,
  }) async {
    final amt = amount == null ? 0 : wownero.Wallet_amountFromString(amount);

    final addressPointer = address.toNativeUtf8();
    final paymentIdAddress = paymentId.toNativeUtf8();
    final preferredInputsPointer =
        preferredInputs.join(wownero.defaultSeparatorStr).toNativeUtf8();

    final walletPointerAddress = _getWalletPointer().address;
    final addressPointerAddress = addressPointer.address;
    final paymentIdPointerAddress = paymentIdAddress.address;
    final preferredInputsPointerAddress = preferredInputsPointer.address;
    final separatorPointerAddress = wownero.defaultSeparator.address;
    final pendingTxPointer = Pointer<Void>.fromAddress(await Isolate.run(() {
      final tx = wownero_gen.WowneroC(DynamicLibrary.open(wownero.libPath))
          .WOWNERO_Wallet_createTransaction(
        Pointer.fromAddress(walletPointerAddress),
        Pointer.fromAddress(addressPointerAddress).cast(),
        Pointer.fromAddress(paymentIdPointerAddress).cast(),
        amt,
        1,
        priority.value,
        accountIndex,
        Pointer.fromAddress(preferredInputsPointerAddress).cast(),
        Pointer.fromAddress(separatorPointerAddress),
      );
      return tx.address;
    }));
    calloc.free(addressPointer);
    calloc.free(paymentIdAddress);
    calloc.free(preferredInputsPointer);
    final String? error = (() {
      final status = wownero.PendingTransaction_status(pendingTxPointer);
      if (status == 0) {
        return null;
      }
      return wownero.PendingTransaction_errorString(pendingTxPointer);
    })();

    if (error != null) {
      final message = error;
      throw CreationTransactionException(message: message);
    }

    final rAmt = wownero.PendingTransaction_amount(pendingTxPointer);
    final rFee = wownero.PendingTransaction_fee(pendingTxPointer);
    final rHash = wownero.PendingTransaction_txid(pendingTxPointer, '');
    final rTxKey = rHash;

    return PendingTransactionDescription(
      amount: rAmt,
      fee: rFee,
      hash: rHash,
      hex: '',
      txKey: rTxKey,
      pointerAddress: pendingTxPointer.address,
    );
  }

  @override
  Future<PendingTransactionDescription> createTransactionMultiDest({
    required List<Output> outputs,
    required String paymentId,
    required TransactionPriority priority,
    int accountIndex = 0,
    required List<String> preferredInputs,
  }) async {
    final pendingTxPointer = wownero.Wallet_createTransactionMultDest(
      _getWalletPointer(),
      dstAddr: outputs.map((e) => e.address!).toList(),
      isSweepAll: false,
      amounts: outputs
          .map((e) => wownero.Wallet_amountFromString(e.amount))
          .toList(),
      mixinCount: 0,
      pendingTransactionPriority: priority.value,
      subaddr_account: accountIndex,
    );
    if (wownero.PendingTransaction_status(pendingTxPointer) != 0) {
      throw CreationTransactionException(
          message: wownero.PendingTransaction_errorString(pendingTxPointer));
    }
    return PendingTransactionDescription(
      amount: wownero.PendingTransaction_amount(pendingTxPointer),
      fee: wownero.PendingTransaction_fee(pendingTxPointer),
      hash: wownero.PendingTransaction_txid(pendingTxPointer, ''),
      hex: wownero.PendingTransaction_txid(pendingTxPointer, ''),
      txKey: wownero.PendingTransaction_txid(pendingTxPointer, ''),
      pointerAddress: pendingTxPointer.address,
    );
  }

  @override
  void commitTransaction({
    required PendingTransactionDescription pendingTransaction,
  }) {
    final transactionPointer = wownero.PendingTransaction.fromAddress(
      pendingTransaction.pointerAddress!,
    );

    wownero.PendingTransaction_commit(transactionPointer,
        filename: '', overwrite: false);

    final String? error = (() {
      final status =
          wownero.PendingTransaction_status(transactionPointer.cast());
      if (status == 0) {
        return null;
      }
      return wownero.Wallet_errorString(_getWalletPointer());
    })();

    if (error != null) {
      throw CreationTransactionException(message: error);
    }
  }
}
