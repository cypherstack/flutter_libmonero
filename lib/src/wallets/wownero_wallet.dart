import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_libmonero/compat/old_cw_core/get_height_by_date.dart';
import 'package:monero/src/generated_bindings_wownero.g.dart' as wownero_gen;
import 'package:monero/wownero.dart' as wownero;

import '../enums/transaction_priority.dart';
import '../enums/wownero_seed_type.dart';
import '../exceptions/creation_transaction_exception.dart';
import '../exceptions/setup_wallet_exception.dart';
import '../exceptions/wallet_creation_exception.dart';
import '../exceptions/wallet_opening_exception.dart';
import '../exceptions/wallet_restore_from_keys_exception.dart';
import '../exceptions/wallet_restore_from_seed_exception.dart';
import '../logging.dart';
import '../mixins/polling.dart';
import '../models/account.dart';
import '../models/address.dart';
import '../models/output.dart';
import '../models/pending_transaction.dart';
import '../models/recipient.dart';
import '../models/transaction.dart';
import '../wallet.dart';

class WowneroWallet extends Wallet with Polling {
  // internal constructor
  WowneroWallet._(wownero.wallet pointer, String path)
      : _walletPointer = pointer,
        _path = path;
  final String _path;

  // shared pointer
  static wownero.WalletManager? __wmPtr;
  static final wownero.WalletManager _wmPtr = Pointer.fromAddress((() {
    try {
      // wownero.printStarts = true;
      __wmPtr ??= wownero.WalletManagerFactory_getWalletManager();
      Logging.log?.i("ptr: $__wmPtr");
    } catch (e, s) {
      Logging.log?.e("Failed to initialize wm ptr", error: e, stackTrace: s);
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
      restoreHeight = wownero.Wallet_getRefreshFromBlockHeight(walletPointer);
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
      Logging.log?.e("err: $err", stackTrace: StackTrace.current);
      throw WalletRestoreFromKeysException(message: err);
    }

    // wownero.Wallet_setCacheAttribute(
    //   walletPointer,
    //   key: "cakewallet.seed",
    //   value: seed,
    // );
    final wallet = WowneroWallet._(walletPointer, path);
    wallet.save();
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
      Logging.log?.e("", error: e, stackTrace: s);
      rethrow;
    }

    final status = wownero.Wallet_status(wallet._getWalletPointer());
    if (status != 0) {
      final err = wownero.Wallet_errorString(wallet._getWalletPointer());
      Logging.log?.e("status: " + err);

      throw WalletOpeningException(message: err);
    }
    return wallet;
  }

  // ===========================================================================

  // special check to see if wallet exists
  static bool isWalletExist(String path) =>
      wownero.WalletManager_walletExists(_wmPtr, path);

// ===========================================================================

  // === Internal overrides ====================================================
  @override
  @protected
  Future<void> refreshOutputs() async {
    _coinsPointer = wownero.Wallet_coins(_getWalletPointer());
    final pointerAddress = _coinsPointer!.address;
    await Isolate.run(() {
      wownero.Coins_refresh(
        Pointer.fromAddress(
          pointerAddress,
        ),
      );
    });
  }

  @override
  @protected
  Future<void> refreshTransactions() async {
    _transactionHistoryPointer = wownero.Wallet_history(_getWalletPointer());
    final pointerAddress = _transactionHistoryPointer!.address;

    await Isolate.run(() {
      wownero.TransactionHistory_refresh(
        Pointer.fromAddress(
          pointerAddress,
        ),
      );
    });
  }

  @override
  @protected
  int transactionCount() =>
      wownero.TransactionHistory_count(_transactionHistoryPointer!);

  @override
  @protected
  int syncHeight() => wownero.Wallet_blockChainHeight(_getWalletPointer());

  // ===========================================================================
  // === Overrides =============================================================

  @override
  int getBlockChainHeightByDate(DateTime date) {
    // TODO: find something not hardcoded
    return getWowneroHeightByDate(date: date);
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
      Logging.log?.i("init (initConnection()) status: $status");
      Logging.log?.i("init (initConnection()) error: $err");
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
  bool isViewOnly() {
    final isWatchOnly = wownero.Wallet_watchOnly(_getWalletPointer());
    return isWatchOnly;
  }

  @override
  void setProxyUri(String proxyUri) {
    wownero.Wallet_setProxy(_getWalletPointer(), address: proxyUri);
  }

  @override
  Future<bool> isConnectedToDaemon() async {
    final address = _getWalletPointer().address;
    final result = await Isolate.run(() {
      return wownero.Wallet_connected(Pointer.fromAddress(address));
    });
    return result == 1;
  }

  @override
  String getPath() {
    final path = wownero.Wallet_path(_getWalletPointer());
    return path;
  }

  @override
  String getSeed() {
    final polySeed =
        wownero.Wallet_getPolyseed(_getWalletPointer(), passphrase: '');
    if (polySeed != "") {
      return polySeed;
    }
    final legacy = wownero.Wallet_seed(_getWalletPointer(), seedOffset: '');
    return legacy;
  }

  @override
  String getSeedLanguage() {
    final language = wownero.Wallet_getSeedLanguage(_getWalletPointer());
    return language;
  }

  @override
  String getPrivateSpendKey() {
    return wownero.Wallet_secretSpendKey(_getWalletPointer());
  }

  @override
  String getPrivateViewKey() {
    return wownero.Wallet_secretViewKey(_getWalletPointer());
  }

  @override
  String getPublicSpendKey() {
    return wownero.Wallet_publicSpendKey(_getWalletPointer());
  }

  @override
  String getPublicViewKey() {
    return wownero.Wallet_publicViewKey(_getWalletPointer());
  }

  @override
  Address getAddress({int accountIndex = 0, int addressIndex = 0}) {
    final address = Address(
      value: wownero.Wallet_address(
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
    return wownero.Wallet_daemonBlockChainHeight(_getWalletPointer());
  }

  @override
  int getSyncFromBlockHeight() =>
      wownero.Wallet_getRefreshFromBlockHeight(_getWalletPointer());

  @override
  void setStartSyncFromBlockHeight(int startHeight) {
    wownero.Wallet_setRefreshFromBlockHeight(
      _getWalletPointer(),
      refresh_from_block_height: startHeight,
    );
  }

  @override
  void startSyncing({Duration interval = const Duration(seconds: 20)}) {
    // TODO: duration
    wownero.Wallet_refreshAsync(_getWalletPointer());
    wownero.Wallet_startRefresh(_getWalletPointer());
  }

  @override
  void stopSyncing() {
    wownero.Wallet_pauseRefresh(_getWalletPointer());
    wownero.Wallet_stop(_getWalletPointer());
  }

  /// returns true on success
  @override
  Future<bool> rescanSpent() async {
    final address = _getWalletPointer().address;
    final result = await Isolate.run(() {
      return wownero.Wallet_rescanSpent(Pointer.fromAddress(address));
    });
    return result;
  }

  /// returns true on success
  @override
  Future<bool> rescanBlockchain() async {
    final address = _getWalletPointer().address;
    final result = await Isolate.run(() {
      return wownero.Wallet_rescanBlockchain(Pointer.fromAddress(address));
    });
    return result;
  }

  @override
  int getBalance({int accountIndex = 0}) => wownero.Wallet_balance(
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
  List<Account> getAccounts({bool includeSubaddresses = false, String? tag}) {
    final accountsCount =
        wownero.Wallet_numSubaddressAccounts(_getWalletPointer());
    final accountsPointer =
        wownero.Wallet_subaddressAccount(_getWalletPointer());
    final accountsSize = wownero.AddressBook_getAll_size(accountsPointer);

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
    wownero.Wallet_addSubaddressAccount(_getWalletPointer(),
        label: label ?? "");
  }

  @override
  void setAccountLabel(int accountIdx, String label) {
    throw UnimplementedError("TODO");
  }

  @override
  void setSubaddressLabel(int accountIdx, int addressIdx, String label) {
    wownero.Wallet_setSubaddressLabel(
      _getWalletPointer(),
      accountIndex: accountIdx,
      addressIndex: addressIdx,
      label: label,
    );
  }

  @override
  String getTxKey(String txId) {
    return wownero.Wallet_getTxKey(_getWalletPointer(), txid: txId);
  }

  @override
  Transaction getTx(String txId) {
    return Transaction(
      txInfo: wownero.TransactionHistory_transactionById(
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
        txInfo: wownero.TransactionHistory_transaction(
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

      // final count = wownero.Coins_getAll_size(_coinsPointer!);
      // why tho?
      final count = wownero.Coins_count(_coinsPointer!);

      Logging.log?.i("monero::found_utxo_count=$count");

      final List<Output> result = [];

      for (int i = 0; i < count; i++) {
        final coinPointer = wownero.Coins_coin(_coinsPointer!, i);

        final hash = wownero.CoinsInfo_hash(coinPointer);

        if (hash.isNotEmpty) {
          final spent = wownero.CoinsInfo_spent(coinPointer);

          if (includeSpent || !spent) {
            final utxo = Output(
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
      return wownero.Wallet_exportKeyImages(
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
      return wownero.Wallet_importKeyImages(
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
  Future<void> thawOutput(String keyImage) async {
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
  Future<PendingTransaction> createTx({
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

    return PendingTransaction(
      amount: wownero.PendingTransaction_amount(pendingTxPointer),
      fee: wownero.PendingTransaction_fee(pendingTxPointer),
      txid: wownero.PendingTransaction_txid(pendingTxPointer, ''),
      hex: wownero.PendingTransaction_hex(pendingTxPointer, ""),
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
    final pendingTxPointer = wownero.Wallet_createTransactionMultDest(
      _getWalletPointer(),
      dstAddr: outputs.map((e) => e.address).toList(),
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
        message: wownero.PendingTransaction_errorString(pendingTxPointer),
      );
    }
    return PendingTransaction(
      amount: wownero.PendingTransaction_amount(pendingTxPointer),
      fee: wownero.PendingTransaction_fee(pendingTxPointer),
      txid: wownero.PendingTransaction_txid(pendingTxPointer, ''),
      hex: wownero.PendingTransaction_hex(pendingTxPointer, ''),
      pointerAddress: pendingTxPointer.address,
    );
  }

  @override
  Future<bool> commitTx(PendingTransaction tx) async {
    final transactionPointer = wownero.PendingTransaction.fromAddress(
      tx.pointerAddress!,
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
      return wownero.Wallet_signMessage(
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
      return wownero.Wallet_verifySignedMessage(
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
    return wownero.Wallet_getPassword(_getWalletPointer());
  }

  @override
  void changePassword(String newPassword) {
    wownero.Wallet_setPassword(_getWalletPointer(), password: newPassword);
  }

  @override
  Future<void> save() async {
    final pointerAddress = _getWalletPointer().address;
    await Isolate.run(() {
      wownero.Wallet_store(Pointer.fromAddress(pointerAddress));
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
  //   wownero.WalletManager_closeWallet(_wmPtr, _getWalletPointer(), save);
  // }

  @override
  bool isClosed() {
    return _walletPointer == null;
  }
}
