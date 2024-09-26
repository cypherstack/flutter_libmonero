import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:cw_core/sub_address.dart';
import 'package:cw_core/sub_address_info_meta_data.dart';
import 'package:cw_monero/api/exceptions/setup_wallet_exception.dart';
import 'package:cw_monero/api/structs/pending_transaction.dart';
import 'package:cw_monero/api/transaction_history.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:monero/monero.dart' as monero;
import 'package:monero/src/generated_bindings_monero.g.dart' as monero_gen;

import 'exceptions/creation_transaction_exception.dart';
import 'monero_output.dart';

class XMRWallet {
  XMRWallet({required monero.wallet walletPointer})
      : _walletPointer = walletPointer;

  int _wlptrForW = 0;
  monero.WalletListener? _walletListenerPointer;
  final monero.wallet _walletPointer;

  monero.wallet get wptr => _walletPointer;

  monero.WalletListener getWlptr() {
    if (wptr.address == _wlptrForW) return _walletListenerPointer!;
    _wlptrForW = wptr.address;
    _walletListenerPointer = monero.MONERO_cw_getWalletListener(wptr);
    return _walletListenerPointer!;
  }

  // ============== Sync Listeners =============================================
  void Function(int, int, double)? onNewBlock;
  void Function()? onNewTransaction;

  Timer? _updateSyncInfoTimer;
  int _cachedBlockchainHeight = 0;
  int _lastKnownBlockHeight = 0;
  int _initialSyncHeight = 0;

  Future<int> getNodeHeightOrUpdate(int baseHeight) async {
    if (_cachedBlockchainHeight < baseHeight || _cachedBlockchainHeight == 0) {
      _cachedBlockchainHeight = await getNodeHeight();
    }

    return _cachedBlockchainHeight;
  }

  void startListeners() {
    _updateSyncInfoTimer ??=
        Timer.periodic(Duration(milliseconds: 1200), (_) async {
      if (isNewTransactionExist()) {
        onNewTransaction?.call();
      }

      var syncHeight = getSyncingHeight();

      if (syncHeight <= 0) {
        syncHeight = getCurrentHeight();
      }

      if (_initialSyncHeight <= 0) {
        _initialSyncHeight = syncHeight;
      }

      final bchHeight = await getNodeHeightOrUpdate(syncHeight);

      if (_lastKnownBlockHeight == syncHeight) {
        return;
      }

      _lastKnownBlockHeight = syncHeight;
      final track = bchHeight - _initialSyncHeight;
      final diff = track - (bchHeight - syncHeight);
      final ptc = diff <= 0 ? 0.0 : diff / track;
      final left = bchHeight - syncHeight;

      if (syncHeight < 0 || left < 0) {
        return;
      }

      // 1. Actual new height; 2. Blocks left to finish; 3. Progress in percents;
      onNewBlock?.call(syncHeight, left, ptc);
    });
  }

  void stopListeners() {
    _updateSyncInfoTimer?.cancel();
    _updateSyncInfoTimer = null;
  }

  // ===========================================================================

  int getSyncingHeight() {
    // final height = monero.MONERO_cw_WalletListener_height(getWlptr());
    final h2 = monero.Wallet_blockChainHeight(wptr);
    // print("height: $height / $h2");
    return h2;
  }

  bool isNeededToRefresh() {
    final ret = monero.MONERO_cw_WalletListener_isNeedToRefresh(getWlptr());
    monero.MONERO_cw_WalletListener_resetNeedToRefresh(getWlptr());
    return ret;
  }

  bool isNewTransactionExist() {
    final ret =
        monero.MONERO_cw_WalletListener_isNewTransactionExist(getWlptr());
    monero.MONERO_cw_WalletListener_resetIsNewTransactionExist(getWlptr());
    return ret;
  }

  String getFilename() => monero.Wallet_filename(wptr);

  String getSeed() {
    // monero.Wallet_setCacheAttribute(wptr!, key: "cakewallet.seed", value: seed);
    final cakepolyseed =
        monero.Wallet_getCacheAttribute(wptr, key: "cakewallet.seed");
    if (cakepolyseed != "") {
      return cakepolyseed;
    }
    final polyseed = monero.Wallet_getPolyseed(wptr, passphrase: '');
    if (polyseed != "") {
      return polyseed;
    }
    final legacy = monero.Wallet_seed(wptr, seedOffset: '');
    return legacy;
  }

  String getAddress({int accountIndex = 0, int addressIndex = 1}) =>
      monero.Wallet_address(wptr,
          accountIndex: accountIndex, addressIndex: addressIndex);

  int getFullBalance({int accountIndex = 0}) =>
      monero.Wallet_balance(wptr, accountIndex: accountIndex);

  int getUnlockedBalance({int accountIndex = 0}) =>
      monero.Wallet_unlockedBalance(wptr, accountIndex: accountIndex);

  int getCurrentHeight() => monero.Wallet_blockChainHeight(wptr);

  int getNodeHeightSync() => monero.Wallet_daemonBlockChainHeight(wptr);

  bool isRefreshPending = false;
  bool connected = false;

  Future<bool> setupNodeFuture({
    required String address,
    String? login,
    String? password,
    bool useSSL = false,
    bool isLightWallet = false,
    String? socksProxyAddress,
  }) async {
//   if (kDebugMode) print('''
// {
//   wptr!,
//   daemonAddress: $address,
//   useSsl: $useSSL,
//   proxyAddress: $socksProxyAddress ?? '',
//   daemonUsername: $login ?? '',
//   daemonPassword: $password ?? ''
// }
// ''');

    // Load the wallet as "offline" first
    // the reason being - wallet not initialized errors. we don't want crashes in here (or empty responses from functions).
    // monero.Wallet_init(wptr!, daemonAddress: '');
    if (kDebugMode) print("init (setupNodeFuture()) node address: $address");
    final waddr = wptr.address;
    await Isolate.run(() {
      monero.Wallet_init(
        Pointer.fromAddress(waddr),
        daemonAddress: address,
        daemonUsername: login ?? '',
        daemonPassword: password ?? '',
        proxyAddress: socksProxyAddress ?? '',
        useSsl: useSSL,
        lightWallet: isLightWallet,
      );
    });
    int status = monero.Wallet_status(wptr);
    if (status != 0) {
      final err = monero.Wallet_errorString(wptr);
      if (kDebugMode) print("init (setupNodeFuture()) status: $status");
      if (kDebugMode) print("init (setupNodeFuture()) error: $err");
      throw SetupWalletException(message: err);
    }

    return status == 0;
  }

  void startRefreshSync() {
    monero.Wallet_refreshAsync(wptr);
    monero.Wallet_startRefresh(wptr);
  }

  void setRefreshFromBlockHeight({required int height}) =>
      monero.Wallet_setRefreshFromBlockHeight(wptr,
          refresh_from_block_height: height);

  void setRecoveringFromSeed({required bool isRecovery}) =>
      monero.Wallet_setRecoveringFromSeed(wptr, recoveringFromSeed: isRecovery);

  void storeSync() {
    final addr = wptr.address;
    Isolate.run(() {
      monero.Wallet_store(Pointer.fromAddress(addr));
    });
  }

  void setPasswordSync(String password) {
    monero.Wallet_setPassword(wptr, password: password);

    final status = monero.Wallet_status(wptr);
    if (status == 0) {
      throw Exception(monero.Wallet_errorString(wptr));
    }
  }

  void closeCurrentWallet() {
    monero.Wallet_stop(wptr);
  }

  String getSecretViewKey() => monero.Wallet_secretViewKey(wptr);

  String getPublicViewKey() => monero.Wallet_publicViewKey(wptr);

  String getSecretSpendKey() => monero.Wallet_secretSpendKey(wptr);

  String getPublicSpendKey() => monero.Wallet_publicSpendKey(wptr);

  void _storeSync(Object _) => storeSync();

  Future<bool> _setupNode(Map<String, Object?> args) async {
    final address = args['address'] as String;
    final login = (args['login'] ?? '') as String;
    final password = (args['password'] ?? '') as String;
    final useSSL = args['useSSL'] as bool;
    final isLightWallet = args['isLightWallet'] as bool;
    final socksProxyAddress = (args['socksProxyAddress'] ?? '') as String;

    return setupNodeFuture(
        address: address,
        login: login,
        password: password,
        useSSL: useSSL,
        isLightWallet: isLightWallet,
        socksProxyAddress: socksProxyAddress);
  }

  int _getNodeHeight(Object _) => getNodeHeightSync();

  void startRefresh() => startRefreshSync();

  Future<void> setupNode({
    required String address,
    String? login,
    String? password,
    bool useSSL = false,
    String? socksProxyAddress,
    bool isLightWallet = false,
  }) async =>
      await _setupNode({
        'address': address,
        'login': login,
        'password': password,
        'useSSL': useSSL,
        'isLightWallet': isLightWallet,
        'socksProxyAddress': socksProxyAddress
      });

  Future<void> store() async => _storeSync(0);

  Future<bool> isConnected() async {
    if (isRefreshPending) return connected;
    isRefreshPending = true;
    final addr = wptr.address;
    final result = await Isolate.run(() {
      monero.lib ??= monero_gen.MoneroC(DynamicLibrary.open(monero.libPath));
      return monero.lib!.MONERO_Wallet_connected(Pointer.fromAddress(addr));
    });

    connected = result == 1;
    isRefreshPending = false;

    return connected;
  }

  Future<int> getNodeHeight() async => _getNodeHeight(0);

  void rescanBlockchainAsync() => monero.Wallet_rescanBlockchainAsync(wptr);

  String getSubaddressLabel(int accountIndex, int addressIndex) {
    return monero.Wallet_getSubaddressLabel(wptr,
        accountIndex: accountIndex, addressIndex: addressIndex);
  }

  Future setTrustedDaemon(bool trusted) async =>
      monero.Wallet_setTrustedDaemon(wptr, arg: trusted);

  Future<bool> trustedDaemon() async => monero.Wallet_trustedDaemon(wptr);

  String signMessage(String message, {String address = ""}) {
    return monero.Wallet_signMessage(wptr, message: message, address: address);
  }

  //======== Account list ======================================================

  monero.SubaddressAccount? subaddressAccount;

  bool isUpdatingSubAddressAccount = false;

  void refreshAccounts() {
    try {
      isUpdatingSubAddressAccount = true;
      subaddressAccount = monero.Wallet_subaddressAccount(wptr);
      monero.SubaddressAccount_refresh(subaddressAccount!);
      isUpdatingSubAddressAccount = false;
    } catch (e) {
      isUpdatingSubAddressAccount = false;
      rethrow;
    }
  }

  List<monero.SubaddressAccountRow> getAllAccount() {
    // final size = monero.Wallet_numSubaddressAccounts(wptr!);
    refreshAccounts();
    final int size = monero.SubaddressAccount_getAll_size(subaddressAccount!);
    if (kDebugMode) print("monero.SubaddressAccount_getAll_size: $size");
    if (size == 0) {
      monero.Wallet_addSubaddressAccount(wptr);
      return getAllAccount();
    }
    return List.generate(size, (index) {
      return monero.SubaddressAccount_getAll_byIndex(subaddressAccount!,
          index: index);
    });
  }

  void addAccountSync({required String label}) {
    monero.Wallet_addSubaddressAccount(wptr, label: label);
  }

  void setLabelForAccountSync(
      {required int accountIndex, required String label}) {
    monero.Wallet_setSubaddressLabel(wptr,
        accountIndex: accountIndex, addressIndex: 0, label: label);
  }

  void _addAccount(String label) => addAccountSync(label: label);

  void _setLabelForAccount(Map<String, dynamic> args) {
    final label = args['label'] as String;
    final accountIndex = args['accountIndex'] as int;

    setLabelForAccountSync(label: label, accountIndex: accountIndex);
  }

  Future<void> addAccount({required String label}) async {
    _addAccount(label);
    await store();
  }

  Future<void> setLabelForAccount(
      {required int accountIndex, required String label}) async {
    _setLabelForAccount({'accountIndex': accountIndex, 'label': label});
    await store();
  }

  //===== SubAddress list ======================================================

  bool isUpdatingSubAddressList = false;

  SubaddressInfoMetadata? subaddress;

  void refreshSubaddresses({required int accountIndex}) {
    try {
      isUpdatingSubAddressList = true;
      subaddress = SubaddressInfoMetadata(accountIndex: accountIndex);
      isUpdatingSubAddressList = false;
    } catch (e) {
      isUpdatingSubAddressList = false;
      rethrow;
    }
  }

  List<Subaddress> getAllSubaddresses() {
    final size = monero.Wallet_numSubaddresses(wptr,
        accountIndex: subaddress!.accountIndex);
    return List.generate(size, (index) {
      return Subaddress(
        accountIndex: subaddress!.accountIndex,
        addressIndex: index,
        label: monero.Wallet_getSubaddressLabel(wptr,
            accountIndex: subaddress!.accountIndex, addressIndex: index),
        address: monero.Wallet_address(
          wptr,
          accountIndex: subaddress!.accountIndex,
          addressIndex: index,
        ),
      );
    }).reversed.toList();
  }

  void addSubaddressSync({required int accountIndex, required String label}) {
    monero.Wallet_addSubaddress(wptr, accountIndex: accountIndex, label: label);
    refreshSubaddresses(accountIndex: accountIndex);
  }

  void setLabelForSubaddressSync(
      {required int accountIndex,
      required int addressIndex,
      required String label}) {
    monero.Wallet_setSubaddressLabel(wptr,
        accountIndex: accountIndex, addressIndex: addressIndex, label: label);
  }

  void _addSubaddress(Map<String, dynamic> args) {
    final label = args['label'] as String;
    final accountIndex = args['accountIndex'] as int;

    addSubaddressSync(accountIndex: accountIndex, label: label);
  }

  void _setLabelForSubaddress(Map<String, dynamic> args) {
    final label = args['label'] as String;
    final accountIndex = args['accountIndex'] as int;
    final addressIndex = args['addressIndex'] as int;

    setLabelForSubaddressSync(
        accountIndex: accountIndex, addressIndex: addressIndex, label: label);
  }

  Future<void> addSubaddress(
      {required int accountIndex, required String label}) async {
    _addSubaddress({'accountIndex': accountIndex, 'label': label});
    await store();
  }

  Future<void> setLabelForSubaddress(
      {required int accountIndex,
      required int addressIndex,
      required String label}) async {
    _setLabelForSubaddress({
      'accountIndex': accountIndex,
      'addressIndex': addressIndex,
      'label': label
    });
    await store();
  }

  //===== Transaction History ==================================================
  monero.TransactionHistory? txhistory;

  String getTxKey(String txId) {
    return monero.Wallet_getTxKey(wptr, txid: txId);
  }

  void refreshTransactions() {
    txhistory = monero.Wallet_history(wptr);
    monero.TransactionHistory_refresh(txhistory!);
  }

  int countOfTransactions() => monero.TransactionHistory_count(txhistory!);

  List<Transaction> getAllTransactions() {
    final size = countOfTransactions();

    return List.generate(
      size,
      (index) => Transaction(
          txInfo:
              monero.TransactionHistory_transaction(txhistory!, index: index),
          getTxKey: getTxKey),
    );
  }

  Transaction getTransaction(String txId) {
    return Transaction(
      txInfo: monero.TransactionHistory_transactionById(txhistory!, txid: txId),
      getTxKey: getTxKey,
    );
  }

  Future<PendingTransactionDescription> createTransactionSync({
    required String address,
    required String paymentId,
    required int priorityRaw,
    String? amount,
    int accountIndex = 0,
    required List<String> preferredInputs,
  }) async {
    final amt = amount == null ? 0 : monero.Wallet_amountFromString(amount);

    final address_ = address.toNativeUtf8();
    final paymentId_ = paymentId.toNativeUtf8();
    final preferredInputs_ =
        preferredInputs.join(monero.defaultSeparatorStr).toNativeUtf8();

    final waddr = wptr.address;
    final addraddr = address_.address;
    final paymentIdAddr = paymentId_.address;
    final preferredInputsAddr = preferredInputs_.address;
    final spaddr = monero.defaultSeparator.address;
    final pendingTx = Pointer<Void>.fromAddress(await Isolate.run(() {
      final tx = monero_gen.MoneroC(DynamicLibrary.open(monero.libPath))
          .MONERO_Wallet_createTransaction(
        Pointer.fromAddress(waddr),
        Pointer.fromAddress(addraddr).cast(),
        Pointer.fromAddress(paymentIdAddr).cast(),
        amt,
        1,
        priorityRaw,
        accountIndex,
        Pointer.fromAddress(preferredInputsAddr).cast(),
        Pointer.fromAddress(spaddr),
      );
      return tx.address;
    }));
    calloc.free(address_);
    calloc.free(paymentId_);
    calloc.free(preferredInputs_);
    final String? error = (() {
      final status = monero.PendingTransaction_status(pendingTx);
      if (status == 0) {
        return null;
      }
      return monero.PendingTransaction_errorString(pendingTx);
    })();

    if (error != null) {
      final message = error;
      throw CreationTransactionException(message: message);
    }

    final rAmt = monero.PendingTransaction_amount(pendingTx);
    final rFee = monero.PendingTransaction_fee(pendingTx);
    final rHash = monero.PendingTransaction_txid(pendingTx, '');
    final rTxKey = rHash;

    return PendingTransactionDescription(
      amount: rAmt,
      fee: rFee,
      hash: rHash,
      hex: '',
      txKey: rTxKey,
      pointerAddress: pendingTx.address,
    );
  }

  PendingTransactionDescription createTransactionMultDestSync({
    required List<MoneroOutput> outputs,
    required String paymentId,
    required int priorityRaw,
    int accountIndex = 0,
    required List<String> preferredInputs,
  }) {
    final txptr = monero.Wallet_createTransactionMultDest(
      wptr,
      dstAddr: outputs.map((e) => e.address!).toList(),
      isSweepAll: false,
      amounts:
          outputs.map((e) => monero.Wallet_amountFromString(e.amount)).toList(),
      mixinCount: 0,
      pendingTransactionPriority: priorityRaw,
      subaddr_account: accountIndex,
    );
    if (monero.PendingTransaction_status(txptr) != 0) {
      throw CreationTransactionException(
          message: monero.PendingTransaction_errorString(txptr));
    }
    return PendingTransactionDescription(
      amount: monero.PendingTransaction_amount(txptr),
      fee: monero.PendingTransaction_fee(txptr),
      hash: monero.PendingTransaction_txid(txptr, ''),
      hex: monero.PendingTransaction_txid(txptr, ''),
      txKey: monero.PendingTransaction_txid(txptr, ''),
      pointerAddress: txptr.address,
    );
  }

  void commitTransactionFromPointerAddress({required int address}) =>
      commitTransaction(
          transactionPointer: monero.PendingTransaction.fromAddress(address));

  void commitTransaction(
      {required monero.PendingTransaction transactionPointer}) {
    final txCommit = monero.PendingTransaction_commit(transactionPointer,
        filename: '', overwrite: false);

    final String? error = (() {
      final status =
          monero.PendingTransaction_status(transactionPointer.cast());
      if (status == 0) {
        return null;
      }
      return monero.Wallet_errorString(wptr);
    })();

    if (error != null) {
      throw CreationTransactionException(message: error);
    }
  }

  Future<PendingTransactionDescription> _createTransactionSync(Map args) async {
    final address = args['address'] as String;
    final paymentId = args['paymentId'] as String;
    final amount = args['amount'] as String?;
    final priorityRaw = args['priorityRaw'] as int;
    final accountIndex = args['accountIndex'] as int;
    final preferredInputs = args['preferredInputs'] as List<String>;

    return createTransactionSync(
      address: address,
      paymentId: paymentId,
      amount: amount,
      priorityRaw: priorityRaw,
      accountIndex: accountIndex,
      preferredInputs: preferredInputs,
    );
  }

  PendingTransactionDescription _createTransactionMultDestSync(Map args) {
    final outputs = args['outputs'] as List<MoneroOutput>;
    final paymentId = args['paymentId'] as String;
    final priorityRaw = args['priorityRaw'] as int;
    final accountIndex = args['accountIndex'] as int;
    final preferredInputs = args['preferredInputs'] as List<String>;

    return createTransactionMultDestSync(
      outputs: outputs,
      paymentId: paymentId,
      priorityRaw: priorityRaw,
      accountIndex: accountIndex,
      preferredInputs: preferredInputs,
    );
  }

  Future<PendingTransactionDescription> createTransaction({
    required String address,
    required int priorityRaw,
    String? amount,
    String paymentId = '',
    int accountIndex = 0,
    required List<String> preferredInputs,
  }) async =>
      _createTransactionSync({
        'address': address,
        'paymentId': paymentId,
        'amount': amount,
        'priorityRaw': priorityRaw,
        'accountIndex': accountIndex,
        'preferredInputs': preferredInputs,
      });

  Future<PendingTransactionDescription> createTransactionMultDest({
    required List<MoneroOutput> outputs,
    required int priorityRaw,
    String paymentId = '',
    int accountIndex = 0,
    required List<String> preferredInputs,
  }) async =>
      _createTransactionMultDestSync({
        'outputs': outputs,
        'paymentId': paymentId,
        'priorityRaw': priorityRaw,
        'accountIndex': accountIndex,
        'preferredInputs': preferredInputs,
      });
}
