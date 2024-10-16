import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_libmonero/compat/old_cw_core/get_height_by_date.dart';
import 'package:monero/monero.dart' as monero;
import 'package:monero/src/generated_bindings_monero.g.dart' as monero_gen;

import '../../flutter_libmonero.dart';
import '../exceptions/setup_wallet_exception.dart';
import '../exceptions/wallet_creation_exception.dart';
import '../exceptions/wallet_opening_exception.dart';
import '../exceptions/wallet_restore_from_keys_exception.dart';
import '../exceptions/wallet_restore_from_seed_exception.dart';
import '../models/account.dart';
import '../models/address.dart';

class MoneroWallet extends Wallet with Polling {
  // internal constructor
  MoneroWallet._(monero.wallet pointer, String path)
      : _walletPointer = pointer,
        _path = path;
  final String _path;

  // shared pointer
  static monero.WalletManager? __wmPtr;
  static final monero.WalletManager _wmPtr = Pointer.fromAddress((() {
    try {
      // monero.printStarts = true;
      __wmPtr ??= monero.WalletManagerFactory_getWalletManager();
      Logging.log?.i("ptr: $__wmPtr");
    } catch (e, s) {
      Logging.log?.e("Failed to initialize wm ptr", error: e, stackTrace: s);
    }
    return __wmPtr!.address;
  })());

  // internal map of wallets
  static final Map<String, MoneroWallet> _openedWalletsByPath = {};

  // instance pointers
  monero.Coins? _coinsPointer;
  monero.TransactionHistory? _transactionHistoryPointer;
  monero.wallet? _walletPointer;
  monero.wallet _getWalletPointer() {
    if (_walletPointer == null) {
      throw Exception(
        "MoneroWallet was closed!",
      );
    }
    return _walletPointer!;
  }

  // ===========================================================================
  //  ==== static factory constructor functions ================================
  static Future<MoneroWallet> create({
    required String path,
    required String password,
    String language = "English",
    required MoneroSeedType seedType,
    int networkType = 0,
  }) async {
    final seed = monero.Wallet_createPolyseed();
    final wptr = monero.WalletManager_createWalletFromPolyseed(
      _wmPtr,
      path: path,
      password: password,
      mnemonic: seed,
      seedOffset: '',
      newWallet: true,
      restoreHeight: 0,
      kdfRounds: 1,
    );

    final status = monero.Wallet_status(wptr);
    if (status != 0) {
      throw WalletCreationException(message: monero.Wallet_errorString(wptr));
    }

    final address = wptr.address;
    await Isolate.run(() {
      monero.Wallet_store(Pointer.fromAddress(address), path: path);
    });

    final wallet = MoneroWallet._(wptr, path);
    _openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static Future<MoneroWallet> restoreWalletFromSeed({
    required String path,
    required String password,
    required String seed,
    int networkType = 0,
    int restoreHeight = 0,
  }) async {
    final monero.wallet wptr;
    final seedLength = seed.split(' ').length;
    if (seedLength == 25) {
      wptr = monero.WalletManager_recoveryWallet(
        _wmPtr,
        path: path,
        password: password,
        mnemonic: seed,
        restoreHeight: restoreHeight,
        seedOffset: '',
        networkType: networkType,
      );
    } else if (seedLength == 16) {
      wptr = monero.WalletManager_createWalletFromPolyseed(
        _wmPtr,
        path: path,
        password: password,
        mnemonic: seed,
        seedOffset: '',
        newWallet: false,
        restoreHeight: restoreHeight,
        kdfRounds: 1,
        networkType: networkType,
      );
    } else {
      throw Exception("Bad seed length: $seedLength");
    }

    final status = monero.Wallet_status(wptr);

    if (status != 0) {
      final error = monero.Wallet_errorString(wptr);
      throw WalletRestoreFromSeedException(message: error);
    }

    final address = wptr.address;
    await Isolate.run(() {
      monero.Wallet_store(Pointer.fromAddress(address), path: path);
    });

    final wallet = MoneroWallet._(wptr, path);
    _openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static MoneroWallet restoreWalletFromKeys({
    required String path,
    required String password,
    required String language,
    required String address,
    required String viewKey,
    required String spendKey,
    int nettype = 0,
    int restoreHeight = 0,
  }) {
    final wptr = monero.WalletManager_createWalletFromKeys(
      _wmPtr,
      path: path,
      password: password,
      restoreHeight: restoreHeight,
      addressString: address,
      viewKeyString: viewKey,
      spendKeyString: spendKey,
      nettype: 0,
    );

    final status = monero.Wallet_status(wptr);
    if (status != 0) {
      throw WalletRestoreFromKeysException(
        message: monero.Wallet_errorString(wptr),
      );
    }

    final wallet = MoneroWallet._(wptr, path);
    _openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static MoneroWallet restoreWalletFromSpendKey({
    required String path,
    required String password,
    // required String seed,
    required String language,
    required String spendKey,
    int nettype = 0,
    int restoreHeight = 0,
  }) {
    final wptr = monero.WalletManager_createDeterministicWalletFromSpendKey(
      _wmPtr,
      path: path,
      password: password,
      language: language,
      spendKeyString: spendKey,
      newWallet: true, // TODO(mrcyjanek): safe to remove
      restoreHeight: restoreHeight,
    );

    final status = monero.Wallet_status(wptr);

    if (status != 0) {
      final err = monero.Wallet_errorString(wptr);
      Logging.log?.e("err: $err", stackTrace: StackTrace.current);
      throw WalletRestoreFromKeysException(message: err);
    }

    // monero.Wallet_setCacheAttribute(wptr, key: "cakewallet.seed", value: seed);
    final wallet = MoneroWallet._(wptr, path);
    wallet.save();
    _openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static MoneroWallet loadWallet({
    required String path,
    required String password,
    int networkType = 0,
  }) {
    MoneroWallet? wallet = _openedWalletsByPath[path];
    if (wallet != null) {
      return wallet;
    }

    try {
      final wptr = monero.WalletManager_openWallet(
        _wmPtr,
        path: path,
        password: password,
      );
      wallet = MoneroWallet._(wptr, path);
      _openedWalletsByPath[path] = wallet;
    } catch (e, s) {
      Logging.log?.e("", error: e, stackTrace: s);
      rethrow;
    }

    final status = monero.Wallet_status(wallet._getWalletPointer());
    if (status != 0) {
      final err = monero.Wallet_errorString(wallet._getWalletPointer());
      Logging.log?.e("status: " + err);
      throw WalletOpeningException(message: err);
    }
    return wallet;
  }

  // special check to see if wallet exists
  static bool isWalletExist(String path) =>
      monero.WalletManager_walletExists(_wmPtr, path);

// ===========================================================================
  // === Internal overrides ====================================================

  @override
  @protected
  Future<void> refreshOutputs() async {
    _coinsPointer = monero.Wallet_coins(_getWalletPointer());
    final pointerAddress = _coinsPointer!.address;
    await Isolate.run(() {
      monero.Coins_refresh(
        Pointer.fromAddress(
          pointerAddress,
        ),
      );
    });
  }

  @override
  @protected
  Future<void> refreshTransactions() async {
    _transactionHistoryPointer = monero.Wallet_history(_getWalletPointer());
    final pointerAddress = _transactionHistoryPointer!.address;

    await Isolate.run(() {
      monero.TransactionHistory_refresh(
        Pointer.fromAddress(
          pointerAddress,
        ),
      );
    });
  }

  @override
  @protected
  int transactionCount() =>
      monero.TransactionHistory_count(_transactionHistoryPointer!);

  @override
  @protected
  int syncHeight() => monero.Wallet_blockChainHeight(_getWalletPointer());

  // ===========================================================================
  // === Overrides =============================================================

  @override
  int getBlockChainHeightByDate(DateTime date) {
    // TODO: find something not hardcoded
    return getMoneroHeigthByDate(date: date);
  }

  @override
  Future<bool> connect({
    required String daemonAddress,
    required bool trusted,
    String? daemonUsername,
    String? daemonPassword,
    bool useSSL = false,
    bool isLightWallet = false,
    String? socksProxyAddress,
  }) async {
    Logging.log?.i("init (initConnection()) node address: $daemonAddress");
    final pointerAddress = _getWalletPointer().address;
    await Isolate.run(() {
      monero.Wallet_init(
        Pointer.fromAddress(pointerAddress),
        daemonAddress: daemonAddress,
        daemonUsername: daemonUsername ?? '',
        daemonPassword: daemonPassword ?? '',
        proxyAddress: socksProxyAddress ?? '',
        useSsl: useSSL,
        lightWallet: isLightWallet,
      );
    });
    final status = monero.Wallet_status(_getWalletPointer());
    if (status != 0) {
      final err = monero.Wallet_errorString(_getWalletPointer());
      Logging.log?.i("init (initConnection()) status: $status");
      Logging.log?.i("init (initConnection()) error: $err");
      throw SetupWalletException(message: err);
    }

    // TODO error handling?
    monero.Wallet_setTrustedDaemon(
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
      () => monero.Wallet_createWatchOnly(
        _getWalletPointer(),
        path: path,
        password: password,
        language: language,
      ),
    );
  }

  @override
  bool isViewOnly() {
    final isWatchOnly = monero.Wallet_watchOnly(_getWalletPointer());
    return isWatchOnly;
  }

  @override
  void setProxyUri(String proxyUri) {
    monero.Wallet_setProxy(_getWalletPointer(), address: proxyUri);
  }

  @override
  Future<bool> isConnectedToDaemon() async {
    final address = _getWalletPointer().address;
    final result = await Isolate.run(() {
      return monero.Wallet_connected(Pointer.fromAddress(address));
    });
    return result == 1;
  }

  @override
  String getPath() {
    final path = monero.Wallet_path(_getWalletPointer());
    return path;
  }

  @override
  String getSeed() {
    final polySeed =
        monero.Wallet_getPolyseed(_getWalletPointer(), passphrase: '');
    if (polySeed != "") {
      return polySeed;
    }
    final legacy = monero.Wallet_seed(_getWalletPointer(), seedOffset: '');
    return legacy;
  }

  @override
  String getSeedLanguage() {
    final language = monero.Wallet_getSeedLanguage(_getWalletPointer());
    return language;
  }

  @override
  String getPrivateSpendKey() {
    return monero.Wallet_secretSpendKey(_getWalletPointer());
  }

  @override
  String getPrivateViewKey() {
    return monero.Wallet_secretViewKey(_getWalletPointer());
  }

  @override
  String getPublicSpendKey() {
    return monero.Wallet_publicSpendKey(_getWalletPointer());
  }

  @override
  String getPublicViewKey() {
    return monero.Wallet_publicViewKey(_getWalletPointer());
  }

  @override
  Address getAddress({int accountIndex = 0, int addressIndex = 0}) {
    final address = Address(
      value: monero.Wallet_address(
        _getWalletPointer(),
        accountIndex: accountIndex,
        addressIndex: addressIndex,
      ),
      account: accountIndex,
      index: addressIndex,
    );

    return address;
  }

  @override
  int getDaemonHeight() {
    return monero.Wallet_daemonBlockChainHeight(_getWalletPointer());
  }

  @override
  int getSyncFromBlockHeight() =>
      monero.Wallet_getRefreshFromBlockHeight(_getWalletPointer());

  @override
  void setStartSyncFromBlockHeight(int startHeight) {
    monero.Wallet_setRefreshFromBlockHeight(
      _getWalletPointer(),
      refresh_from_block_height: startHeight,
    );
  }

  @override
  void startSyncing({Duration interval = const Duration(seconds: 20)}) {
    // TODO: duration
    monero.Wallet_refreshAsync(_getWalletPointer());
    monero.Wallet_startRefresh(_getWalletPointer());
  }

  @override
  void stopSyncing() {
    monero.Wallet_pauseRefresh(_getWalletPointer());
    monero.Wallet_stop(_getWalletPointer());
  }

  /// returns true on success
  @override
  Future<bool> rescanSpent() async {
    final address = _getWalletPointer().address;
    final result = await Isolate.run(() {
      return monero.Wallet_rescanSpent(Pointer.fromAddress(address));
    });
    return result;
  }

  /// returns true on success
  @override
  Future<bool> rescanBlockchain() async {
    final address = _getWalletPointer().address;
    final result = await Isolate.run(() {
      return monero.Wallet_rescanBlockchain(Pointer.fromAddress(address));
    });
    return result;
  }

  @override
  int getBalance({int accountIndex = 0}) => monero.Wallet_balance(
        _getWalletPointer(),
        accountIndex: accountIndex,
      );

  @override
  int getUnlockedBalance({int accountIndex = 0}) =>
      monero.Wallet_unlockedBalance(
        _getWalletPointer(),
        accountIndex: accountIndex,
      );

  @override
  List<Account> getAccounts({bool includeSubaddresses = false, String? tag}) {
    final accountsCount =
        monero.Wallet_numSubaddressAccounts(_getWalletPointer());
    final accountsPointer =
        monero.Wallet_subaddressAccount(_getWalletPointer());
    final accountsSize = monero.AddressBook_getAll_size(accountsPointer);

    // TODO:
    // for (int i = 0 ; i < accountsCount; i++) {
    //   final primaryAddress = getAddress(accountIndex: i, addressIndex: 0);
    //
    //   final account = Account(index: i, primaryAddress: primaryAddress.value,
    //       balance: balance,
    //       unlockedBalance: unlockedBalance,
    //       tag: tag,
    //       subaddresses: subaddresses,
    //   );
    // }
    //
    throw UnimplementedError("TODO");
  }

  @override
  Account getAccount(int accountIdx, {bool includeSubaddresses = false}) {
    throw UnimplementedError("TODO");
  }

  @override
  void createAccount({String? label}) {
    monero.Wallet_addSubaddressAccount(_getWalletPointer(), label: label ?? "");
  }

  @override
  void setAccountLabel(int accountIdx, String label) {
    throw UnimplementedError("TODO");
  }

  @override
  void setSubaddressLabel(int accountIdx, int addressIdx, String label) {
    monero.Wallet_setSubaddressLabel(
      _getWalletPointer(),
      accountIndex: accountIdx,
      addressIndex: addressIdx,
      label: label,
    );
  }

  @override
  String getTxKey(String txId) {
    return monero.Wallet_getTxKey(_getWalletPointer(), txid: txId);
  }

  @override
  Transaction getTx(String txId) {
    return Transaction(
      txInfo: monero.TransactionHistory_transactionById(
        _transactionHistoryPointer!,
        txid: txId,
      ),
      getTxKey: getTxKey,
    );
  }

  @override
  List<Transaction> getTxs() {
    final size = transactionCount();

    return List.generate(
      size,
      (index) => Transaction(
        txInfo: monero.TransactionHistory_transaction(
          _transactionHistoryPointer!,
          index: index,
        ),
        getTxKey: getTxKey,
      ),
    );
  }

  @override
  Future<List<Output>> getOutputs({bool includeSpent = false}) async {
    try {
      await refreshOutputs();

      // final count = monero.Coins_getAll_size(_coinsPointer!);
      // why tho?
      final count = monero.Coins_count(_coinsPointer!);

      Logging.log?.i("monero::found_utxo_count=$count");

      final List<Output> result = [];

      for (int i = 0; i < count; i++) {
        final coinPointer = monero.Coins_coin(_coinsPointer!, i);

        final hash = monero.CoinsInfo_hash(coinPointer);

        if (hash.isNotEmpty) {
          final spent = monero.CoinsInfo_spent(coinPointer);

          if (includeSpent || !spent) {
            final utxo = Output(
              address: monero.CoinsInfo_address(coinPointer),
              hash: hash,
              keyImage: monero.CoinsInfo_keyImage(coinPointer),
              value: monero.CoinsInfo_amount(coinPointer),
              isFrozen: monero.CoinsInfo_frozen(coinPointer),
              isUnlocked: monero.CoinsInfo_unlocked(coinPointer),
              vout: monero.CoinsInfo_internalOutputIndex(coinPointer),
              spent: spent,
              height: monero.CoinsInfo_blockHeight(coinPointer),
              coinbase: monero.CoinsInfo_coinbase(coinPointer),
            );

            result.add(utxo);
          }
        } else {
          Logging.log?.w("Found empty hash in monero utxo?!");
        }
      }

      return result;
    } catch (e, s) {
      Logging.log?.w("getOutputs failed", error: e, stackTrace: s);
      rethrow;
    }
  }

  @override
  Future<bool> exportKeyImages({
    required String filename,
    bool all = false,
  }) async {
    final pointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return monero.Wallet_exportKeyImages(
        Pointer<Void>.fromAddress(pointerAddress),
        filename,
        all: all,
      );
    });
  }

  @override
  Future<bool> importKeyImages({required String filename}) async {
    final pointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return monero.Wallet_importKeyImages(
        Pointer<Void>.fromAddress(pointerAddress),
        filename,
      );
    });
  }

  @override
  Future<void> freezeOutput(String keyImage) async {
    if (keyImage.isEmpty) {
      throw Exception("Attempted freeze of empty keyImage.");
    }

    final count = monero.Coins_getAll_size(_coinsPointer!);
    for (int i = 0; i < count; i++) {
      if (keyImage ==
          monero.CoinsInfo_keyImage(monero.Coins_coin(_coinsPointer!, i))) {
        monero.Coins_setFrozen(_coinsPointer!, index: i);
        return;
      }
    }

    throw Exception(
      "Can't freeze utxo for the gen keyImage if it cannot be found. *points at temple*",
    );
  }

  @override
  Future<void> thawOutput(String keyImage) async {
    if (keyImage.isEmpty) {
      throw Exception("Attempted thaw of empty keyImage.");
    }

    final count = monero.Coins_getAll_size(_coinsPointer!);
    for (int i = 0; i < count; i++) {
      if (keyImage ==
          monero.CoinsInfo_keyImage(monero.Coins_coin(_coinsPointer!, i))) {
        monero.Coins_thaw(_coinsPointer!, index: i);
        return;
      }
    }

    throw Exception(
      "Can't thaw utxo for the gen keyImage if it cannot be found. *points at temple*",
    );
  }

  @override
  Future<PendingTransaction> createTx({
    required String address,
    required String paymentId,
    required TransactionPriority priority,
    String? amount,
    int accountIndex = 0,
    required List<String> preferredInputs,
  }) async {
    final amt = amount == null ? 0 : monero.Wallet_amountFromString(amount);

    final addressPointer = address.toNativeUtf8();
    final paymentIdAddress = paymentId.toNativeUtf8();
    final preferredInputsPointer =
        preferredInputs.join(monero.defaultSeparatorStr).toNativeUtf8();

    final walletPointerAddress = _getWalletPointer().address;
    final addressPointerAddress = addressPointer.address;
    final paymentIdPointerAddress = paymentIdAddress.address;
    final preferredInputsPointerAddress = preferredInputsPointer.address;
    final separatorPointerAddress = monero.defaultSeparator.address;
    final pendingTxPointer = Pointer<Void>.fromAddress(await Isolate.run(() {
      final tx = monero_gen.MoneroC(DynamicLibrary.open(monero.libPath))
          .MONERO_Wallet_createTransaction(
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
      final status = monero.PendingTransaction_status(pendingTxPointer);
      if (status == 0) {
        return null;
      }
      return monero.PendingTransaction_errorString(pendingTxPointer);
    })();

    if (error != null) {
      final message = error;
      throw CreationTransactionException(message: message);
    }

    return PendingTransaction(
      amount: monero.PendingTransaction_amount(pendingTxPointer),
      fee: monero.PendingTransaction_fee(pendingTxPointer),
      txid: monero.PendingTransaction_txid(pendingTxPointer, ''),
      hex: monero.PendingTransaction_hex(pendingTxPointer, ""),
      pointerAddress: pendingTxPointer.address,
    );
  }

  @override
  Future<PendingTransaction> createTxMultiDest({
    required List<Recipient> outputs,
    required String paymentId,
    required TransactionPriority priority,
    int accountIndex = 0,
    required List<String> preferredInputs,
  }) async {
    final pendingTxPointer = monero.Wallet_createTransactionMultDest(
      _getWalletPointer(),
      dstAddr: outputs.map((e) => e.address).toList(),
      isSweepAll: false,
      amounts:
          outputs.map((e) => monero.Wallet_amountFromString(e.amount)).toList(),
      mixinCount: 0,
      pendingTransactionPriority: priority.value,
      subaddr_account: accountIndex,
    );
    if (monero.PendingTransaction_status(pendingTxPointer) != 0) {
      throw CreationTransactionException(
        message: monero.PendingTransaction_errorString(pendingTxPointer),
      );
    }
    return PendingTransaction(
      amount: monero.PendingTransaction_amount(pendingTxPointer),
      fee: monero.PendingTransaction_fee(pendingTxPointer),
      txid: monero.PendingTransaction_txid(pendingTxPointer, ''),
      hex: monero.PendingTransaction_hex(pendingTxPointer, ''),
      pointerAddress: pendingTxPointer.address,
    );
  }

  @override
  Future<bool> commitTx(PendingTransaction tx) async {
    final transactionPointer = monero.PendingTransaction.fromAddress(
      tx.pointerAddress!,
    );

    monero.PendingTransaction_commit(transactionPointer,
        filename: '', overwrite: false);

    final String? error = (() {
      final status =
          monero.PendingTransaction_status(transactionPointer.cast());
      if (status == 0) {
        return null;
      }
      return monero.Wallet_errorString(_getWalletPointer());
    })();

    if (error != null) {
      Logging.log?.e(error, stackTrace: StackTrace.current);
      return false;
    } else {
      return true;
    }
  }

  @override
  Future<String> signMessage(
    String message,
    String address,
  ) async {
    final pointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return monero.Wallet_signMessage(
        Pointer.fromAddress(pointerAddress),
        message: message,
        address: address,
      );
    });
  }

  @override
  Future<bool> verifyMessage(
    String message,
    String address,
    String signature,
  ) async {
    final pointerAddress = _getWalletPointer().address;
    return await Isolate.run(() {
      return monero.Wallet_verifySignedMessage(
        Pointer.fromAddress(pointerAddress),
        message: message,
        address: address,
        signature: signature,
      );
    });
  }

  // @override
  // String getPaymentUri(TxConfig request) {
  //   throw UnimplementedError("TODO");
  // }

  @override
  String getPassword() {
    return monero.Wallet_getPassword(_getWalletPointer());
  }

  @override
  void changePassword(String newPassword) {
    monero.Wallet_setPassword(_getWalletPointer(), password: newPassword);
  }

  @override
  Future<void> save() async {
    final pointerAddress = _getWalletPointer().address;
    await Isolate.run(() {
      monero.Wallet_store(Pointer.fromAddress(pointerAddress));
    });
  }

  // @override
  // Future<void> close({bool save = false}) async {
  //   if (isClosed()) return;
  //
  //   if (save) {
  //     await this.save();
  //   }
  //
  //   _walletPointer = null;
  //   _openedWalletsByPath.remove(_path);
  //   monero.WalletManager_closeWallet(_wmPtr, _getWalletPointer(), save);
  // }

  @override
  bool isClosed() {
    return _walletPointer == null;
  }
}
