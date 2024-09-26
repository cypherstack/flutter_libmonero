import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:cw_core/sub_address.dart';
import 'package:cw_core/sub_address_info_meta_data.dart';
import 'package:cw_wownero/api/exceptions/setup_wallet_exception.dart';
import 'package:cw_wownero/api/structs/pending_transaction.dart';
import 'package:cw_wownero/api/transaction_history.dart';
import 'package:cw_wownero/api/wownero_output.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:monero/src/generated_bindings_wownero.g.dart' as wownero_gen;
import 'package:monero/wownero.dart' as wownero;

import 'exceptions/creation_transaction_exception.dart';

class WOWWallet {
  WOWWallet({required wownero.wallet walletPointer})
      : _walletPointer = walletPointer;

  int _wlptrForW = 0;
  wownero.WalletListener? _walletListenerPointer;
  final wownero.wallet _walletPointer;

  wownero.wallet get wptr => _walletPointer;

  wownero.WalletListener getWlptr() {
    if (wptr.address == _wlptrForW) return _walletListenerPointer!;
    _wlptrForW = wptr.address;
    _walletListenerPointer = wownero.WOWNERO_cw_getWalletListener(wptr);
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
    // final height = wownero.WOWNERO_cw_WalletListener_height(getWlptr());
    final h2 = wownero.Wallet_blockChainHeight(wptr);
    // if (kDebugMode) print("height: $height / $h2");
    return h2;
  }

  bool isNeededToRefresh() {
    final ret = wownero.WOWNERO_cw_WalletListener_isNeedToRefresh(getWlptr());
    wownero.WOWNERO_cw_WalletListener_resetNeedToRefresh(getWlptr());
    return ret;
  }

  bool isNewTransactionExist() {
    final ret =
        wownero.WOWNERO_cw_WalletListener_isNewTransactionExist(getWlptr());
    wownero.WOWNERO_cw_WalletListener_resetIsNewTransactionExist(getWlptr());
    return ret;
  }

  String getFilename() => wownero.Wallet_filename(wptr);

  String getSeed() {
    // wownero.Wallet_setCacheAttribute(wptr!, key: "cakewallet.seed", value: seed);
    final cakepolyseed =
        wownero.Wallet_getCacheAttribute(wptr, key: "cakewallet.seed");
    if (cakepolyseed != "") {
      return cakepolyseed;
    }
    final polyseed = wownero.Wallet_getPolyseed(wptr, passphrase: '');
    if (polyseed != "") {
      return polyseed;
    }
    final legacy = wownero.Wallet_seed(wptr, seedOffset: '');
    return legacy;
  }

  String getAddress({int accountIndex = 0, int addressIndex = 1}) =>
      wownero.Wallet_address(wptr,
          accountIndex: accountIndex, addressIndex: addressIndex);

  bool addressValid(String address) => wownero.Wallet_addressValid(address, 0);

  int getFullBalance({int accountIndex = 0}) =>
      wownero.Wallet_balance(wptr, accountIndex: accountIndex);

  int getUnlockedBalance({int accountIndex = 0}) =>
      wownero.Wallet_unlockedBalance(wptr, accountIndex: accountIndex);

  int getCurrentHeight() => wownero.Wallet_blockChainHeight(wptr);

  int getNodeHeightSync() => wownero.Wallet_daemonBlockChainHeight(wptr);

  bool isRefreshPending = false;
  bool connected = false;

  Future<bool> setupNodeFuture(
      {required String address,
      String? login,
      String? password,
      bool useSSL = false,
      bool isLightWallet = false,
      String? socksProxyAddress}) async {
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
    // wownero.Wallet_init(wptr!, daemonAddress: '');
    if (kDebugMode) print("init (setupNodeFuture()) address: $address");
    final waddr = wptr.address;
    final address_ = address.toNativeUtf8().address;
    final username_ = (login ?? '').toNativeUtf8().address;
    final password_ = (password ?? '').toNativeUtf8().address;
    final socksProxyAddress_ = (socksProxyAddress ?? '').toNativeUtf8().address;
    await Isolate.run(() async {
      wownero.lib ??=
          wownero_gen.WowneroC(DynamicLibrary.open(wownero.libPath));
      wownero.lib!.WOWNERO_Wallet_init(
        Pointer.fromAddress(waddr),
        Pointer.fromAddress(address_).cast(),
        0,
        Pointer.fromAddress(username_).cast(),
        Pointer.fromAddress(password_).cast(),
        useSSL,
        isLightWallet,
        Pointer.fromAddress(socksProxyAddress_).cast(),
      );
    });
    calloc.free(Pointer.fromAddress(address_));
    calloc.free(Pointer.fromAddress(username_));
    calloc.free(Pointer.fromAddress(password_));
    calloc.free(Pointer.fromAddress(socksProxyAddress_));
    final status = wownero.Wallet_status(wptr);
    if (status != 0) {
      final err = wownero.Wallet_errorString(wptr);
      if (kDebugMode) print("init (setupNodeFuture()) status: $status");
      if (kDebugMode) print("init (setupNodeFuture()) err: $err");
      throw SetupWalletException(message: err);
    }
    wownero.Wallet_init3(wptr,
        argv0: "stack_wallet",
        defaultLogBaseName: "",
        logPath: "/dev/shm/wow.log",
        console: true);

    return status == 0;
  }

  void startRefreshSync() {
    wownero.Wallet_refreshAsync(wptr);
    wownero.Wallet_startRefresh(wptr);
  }

  Future<bool> connectToNode() async {
    return true;
  }

  void setRefreshFromBlockHeight({required int height}) =>
      wownero.Wallet_setRefreshFromBlockHeight(wptr,
          refresh_from_block_height: height);

  void setRecoveringFromSeed({required bool isRecovery}) =>
      wownero.Wallet_setRecoveringFromSeed(wptr,
          recoveringFromSeed: isRecovery);

  void storeSync() {
    final addr = wptr.address;
    Isolate.run(() {
      wownero.Wallet_store(Pointer.fromAddress(addr));
    });
  }

  void setPasswordSync(String password) {
    wownero.Wallet_setPassword(wptr, password: password);

    final status = wownero.Wallet_status(wptr);
    if (status == 0) {
      throw Exception(wownero.Wallet_errorString(wptr));
    }
  }

  void closeCurrentWallet() {
    wownero.Wallet_stop(wptr);
  }

  String getSecretViewKey() => wownero.Wallet_secretViewKey(wptr);

  String getPublicViewKey() => wownero.Wallet_publicViewKey(wptr);

  String getSecretSpendKey() => wownero.Wallet_secretSpendKey(wptr);

  String getPublicSpendKey() => wownero.Wallet_publicSpendKey(wptr);

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

  Future<void> setupNode(
          {required String address,
          String? login,
          String? password,
          bool useSSL = false,
          String? socksProxyAddress,
          bool isLightWallet = false}) async =>
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
      wownero.lib ??=
          wownero_gen.WowneroC(DynamicLibrary.open(wownero.libPath));
      return wownero.lib!.WOWNERO_Wallet_connected(Pointer.fromAddress(addr));
    });

    connected = result == 1;
    isRefreshPending = false;

    return connected;
  }

  Future<int> getNodeHeight() async => _getNodeHeight(0);

  void rescanBlockchainAsync() => wownero.Wallet_rescanBlockchainAsync(wptr);

  String getSubaddressLabel(int accountIndex, int addressIndex) {
    return wownero.Wallet_getSubaddressLabel(wptr,
        accountIndex: accountIndex, addressIndex: addressIndex);
  }

  Future setTrustedDaemon(bool trusted) async =>
      wownero.Wallet_setTrustedDaemon(wptr, arg: trusted);

  Future<bool> trustedDaemon() async => wownero.Wallet_trustedDaemon(wptr);

  String signMessage(String message, {String address = ""}) {
    return wownero.Wallet_signMessage(wptr, message: message, address: address);
  }

  //======== Account list ======================================================

  wownero.SubaddressAccount? subaddressAccount;

  bool isUpdatingSubAddressAccount = false;

  void refreshAccounts() {
    try {
      isUpdatingSubAddressAccount = true;
      subaddressAccount = wownero.Wallet_subaddressAccount(wptr);
      wownero.SubaddressAccount_refresh(subaddressAccount!);
      isUpdatingSubAddressAccount = false;
    } catch (e) {
      isUpdatingSubAddressAccount = false;
      rethrow;
    }
  }

  List<wownero.SubaddressAccountRow> getAllAccount() {
    // final size = wownero.Wallet_numSubaddressAccounts(wptr!);
    refreshAccounts();
    final int size = wownero.SubaddressAccount_getAll_size(subaddressAccount!);
    if (kDebugMode) print("wownero.SubaddressAccount_getAll_size: $size");
    if (size == 0) {
      wownero.Wallet_addSubaddressAccount(wptr);
      return getAllAccount();
    }
    return List.generate(size, (index) {
      return wownero.SubaddressAccount_getAll_byIndex(subaddressAccount!,
          index: index);
    });
  }

  void addAccountSync({required String label}) {
    wownero.Wallet_addSubaddressAccount(wptr, label: label);
  }

  void setLabelForAccountSync(
      {required int accountIndex, required String label}) {
    wownero.Wallet_setSubaddressLabel(wptr,
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
    final size = wownero.Wallet_numSubaddresses(wptr,
        accountIndex: subaddress!.accountIndex);
    return List.generate(size, (index) {
      return Subaddress(
        accountIndex: subaddress!.accountIndex,
        addressIndex: index,
        label: wownero.Wallet_getSubaddressLabel(wptr,
            accountIndex: subaddress!.accountIndex, addressIndex: index),
        address: wownero.Wallet_address(
          wptr,
          accountIndex: subaddress!.accountIndex,
          addressIndex: index,
        ),
      );
    }).reversed.toList();
  }

  void addSubaddressSync({required int accountIndex, required String label}) {
    wownero.Wallet_addSubaddress(wptr,
        accountIndex: accountIndex, label: label);
    refreshSubaddresses(accountIndex: accountIndex);
  }

  void setLabelForSubaddressSync(
      {required int accountIndex,
      required int addressIndex,
      required String label}) {
    wownero.Wallet_setSubaddressLabel(wptr,
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

  wownero.TransactionHistory? txhistory;

  String getTxKey(String txId) {
    return wownero.Wallet_getTxKey(wptr, txid: txId);
  }

  void refreshTransactions() {
    txhistory = wownero.Wallet_history(wptr);
    wownero.TransactionHistory_refresh(txhistory!);
  }

  int countOfTransactions() => wownero.TransactionHistory_count(txhistory!);

  List<Transaction> getAllTransactions() {
    final size = countOfTransactions();

    return List.generate(
      size,
      (index) => Transaction(
        txInfo: wownero.TransactionHistory_transaction(
          txhistory!,
          index: index,
        ),
        getTxKey: getTxKey,
      ),
    );
  }

  Transaction getTransaction(String txId) {
    return Transaction(
      txInfo: wownero.TransactionHistory_transactionById(
        txhistory!,
        txid: txId,
      ),
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
    final amt = amount == null ? 0 : wownero.Wallet_amountFromString(amount);

    final address_ = address.toNativeUtf8();
    final paymentId_ = paymentId.toNativeUtf8();
    final preferredInputs_ =
        preferredInputs.join(wownero.defaultSeparatorStr).toNativeUtf8();

    final waddr = wptr.address;
    final addraddr = address_.address;
    final paymentIdAddr = paymentId_.address;
    final preferredInputsAddr = preferredInputs_.address;
    final spaddr = wownero.defaultSeparator.address;
    final pendingTx = Pointer<Void>.fromAddress(await Isolate.run(() {
      final tx = wownero_gen.WowneroC(DynamicLibrary.open(wownero.libPath))
          .WOWNERO_Wallet_createTransaction(
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
      final status = wownero.PendingTransaction_status(pendingTx);
      if (status == 0) {
        return null;
      }
      return wownero.PendingTransaction_errorString(pendingTx);
    })();

    if (error != null) {
      final message = error;
      throw CreationTransactionException(message: message);
    }

    final rAmt = wownero.PendingTransaction_amount(pendingTx);
    final rFee = wownero.PendingTransaction_fee(pendingTx);
    final rHash = wownero.PendingTransaction_txid(pendingTx, '');

    return PendingTransactionDescription(
      amount: rAmt,
      fee: rFee,
      hash: rHash,
      pointerAddress: pendingTx.address,
    );
  }

  PendingTransactionDescription createTransactionMultDestSync({
    required List<WowneroOutput> outputs,
    required String paymentId,
    required int priorityRaw,
    int accountIndex = 0,
    required List<String> preferredInputs,
  }) {
    final txptr = wownero.Wallet_createTransactionMultDest(
      wptr,
      dstAddr: outputs.map((e) => e.address!).toList(),
      isSweepAll: false,
      amounts: outputs
          .map((e) => wownero.Wallet_amountFromString(e.amount))
          .toList(),
      mixinCount: 0,
      pendingTransactionPriority: priorityRaw,
      subaddr_account: accountIndex,
      preferredInputs: preferredInputs,
    );
    if (wownero.PendingTransaction_status(txptr) != 0) {
      throw CreationTransactionException(
          message: wownero.PendingTransaction_errorString(txptr));
    }
    return PendingTransactionDescription(
      amount: wownero.PendingTransaction_amount(txptr),
      fee: wownero.PendingTransaction_fee(txptr),
      hash: wownero.PendingTransaction_txid(txptr, ''),
      pointerAddress: txptr.address,
    );
  }

  void commitTransactionFromPointerAddress({required int address}) =>
      commitTransaction(
          transactionPointer: wownero.PendingTransaction.fromAddress(address));

  void commitTransaction(
      {required wownero.PendingTransaction transactionPointer}) {
    final txCommit = wownero.PendingTransaction_commit(transactionPointer,
        filename: '', overwrite: false);

    final String? error = (() {
      final status =
          wownero.PendingTransaction_status(transactionPointer.cast());
      if (status == 0) {
        return null;
      }
      return wownero.Wallet_errorString(wptr);
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
    final outputs = args['outputs'] as List<WowneroOutput>;
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
        'preferredInputs': preferredInputs
      });

  Future<PendingTransactionDescription> createTransactionMultDest({
    required List<WowneroOutput> outputs,
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
        'preferredInputs': preferredInputs
      });
}
