// import 'dart:ffi';
// import 'dart:isolate';
//
// import 'package:ffi/ffi.dart';
// import 'package:flutter/foundation.dart';
// import 'package:monero/monero.dart' as monero;
// import 'package:monero/src/generated_bindings_monero.g.dart' as monero_gen;
//
// import 'enums/monero_seed_type.dart';
// import 'enums/transaction_priority.dart';
// import 'exceptions/creation_transaction_exception.dart';
// import 'exceptions/setup_wallet_exception.dart';
// import 'exceptions/wallet_creation_exception.dart';
// import 'exceptions/wallet_opening_exception.dart';
// import 'exceptions/wallet_restore_from_keys_exception.dart';
// import 'exceptions/wallet_restore_from_seed_exception.dart';
// import 'models/recipient.dart';
// import 'models/transaction.dart';
// import 'models/utxo.dart';
// import 'structs/pending_transaction.dart';
// import 'wallet.dart';
//
// class MoneroWallet implements WalletApi {
//   // internal constructor
//   MoneroWallet._(monero.wallet pointer, String path)
//       : _walletPointer = pointer,
//         _path = path;
//   final String _path;
//
//   // shared pointer
//   static monero.WalletManager? __wmPtr;
//   static final monero.WalletManager _wmPtr = Pointer.fromAddress((() {
//     try {
//       monero.printStarts = true;
//       __wmPtr ??= monero.WalletManagerFactory_getWalletManager();
//       if (kDebugMode) print("ptr: $__wmPtr");
//     } catch (e) {
//       if (kDebugMode) print(e);
//     }
//     return __wmPtr!.address;
//   })());
//
//   // internal map of wallets
//   static final Map<String, MoneroWallet> _openedWalletsByPath = {};
//
//   // instance pointers
//   monero.Coins? _coinsPointer;
//   monero.TransactionHistory? _transactionHistoryPointer;
//   monero.wallet? _walletPointer;
//   monero.wallet _getWalletPointer() {
//     if (_walletPointer == null) {
//       throw Exception(
//         "MoneroWallet was closed!",
//       );
//     }
//     return _walletPointer!;
//   }
//
//   // static factory constructor functions
//   static Future<MoneroWallet> create({
//     required String path,
//     required String password,
//     String language = "English",
//     required MoneroSeedType seedType,
//     int networkType = 0,
//   }) async {
//     final seed = monero.Wallet_createPolyseed();
//     final wptr = monero.WalletManager_createWalletFromPolyseed(
//       _wmPtr,
//       path: path,
//       password: password,
//       mnemonic: seed,
//       seedOffset: '',
//       newWallet: true,
//       restoreHeight: 0,
//       kdfRounds: 1,
//     );
//
//     final status = monero.Wallet_status(wptr);
//     if (status != 0) {
//       throw WalletCreationException(message: monero.Wallet_errorString(wptr));
//     }
//
//     final address = wptr.address;
//     await Isolate.run(() {
//       monero.Wallet_store(Pointer.fromAddress(address), path: path);
//     });
//
//     final wallet = MoneroWallet._(wptr, path);
//     _openedWalletsByPath[path] = wallet;
//     return wallet;
//   }
//
//   static Future<MoneroWallet> restoreWalletFromSeed({
//     required String path,
//     required String password,
//     required String seed,
//     int networkType = 0,
//     int restoreHeight = 0,
//   }) async {
//     final monero.wallet wptr;
//     final seedLength = seed.split(' ').length;
//     if (seedLength == 25) {
//       wptr = monero.WalletManager_recoveryWallet(
//         _wmPtr,
//         path: path,
//         password: password,
//         mnemonic: seed,
//         restoreHeight: restoreHeight,
//         seedOffset: '',
//         networkType: networkType,
//       );
//     } else if (seedLength == 16) {
//       wptr = monero.WalletManager_createWalletFromPolyseed(
//         _wmPtr,
//         path: path,
//         password: password,
//         mnemonic: seed,
//         seedOffset: '',
//         newWallet: false,
//         restoreHeight: restoreHeight,
//         kdfRounds: 1,
//         networkType: networkType,
//       );
//     } else {
//       throw Exception("Bad seed length: $seedLength");
//     }
//
//     final status = monero.Wallet_status(wptr);
//
//     if (status != 0) {
//       final error = monero.Wallet_errorString(wptr);
//       throw WalletRestoreFromSeedException(message: error);
//     }
//
//     final address = wptr.address;
//     await Isolate.run(() {
//       monero.Wallet_store(Pointer.fromAddress(address), path: path);
//     });
//
//     final wallet = MoneroWallet._(wptr, path);
//     _openedWalletsByPath[path] = wallet;
//     return wallet;
//   }
//
//   static MoneroWallet restoreWalletFromKeys({
//     required String path,
//     required String password,
//     required String language,
//     required String address,
//     required String viewKey,
//     required String spendKey,
//     int nettype = 0,
//     int restoreHeight = 0,
//   }) {
//     final wptr = monero.WalletManager_createWalletFromKeys(
//       _wmPtr,
//       path: path,
//       password: password,
//       restoreHeight: restoreHeight,
//       addressString: address,
//       viewKeyString: viewKey,
//       spendKeyString: spendKey,
//       nettype: 0,
//     );
//
//     final status = monero.Wallet_status(wptr);
//     if (status != 0) {
//       throw WalletRestoreFromKeysException(
//         message: monero.Wallet_errorString(wptr),
//       );
//     }
//
//     final wallet = MoneroWallet._(wptr, path);
//     _openedWalletsByPath[path] = wallet;
//     return wallet;
//   }
//
//   static MoneroWallet restoreWalletFromSpendKey({
//     required String path,
//     required String password,
//     // required String seed,
//     required String language,
//     required String spendKey,
//     int nettype = 0,
//     int restoreHeight = 0,
//   }) {
//     final wptr = monero.WalletManager_createDeterministicWalletFromSpendKey(
//       _wmPtr,
//       path: path,
//       password: password,
//       language: language,
//       spendKeyString: spendKey,
//       newWallet: true, // TODO(mrcyjanek): safe to remove
//       restoreHeight: restoreHeight,
//     );
//
//     final status = monero.Wallet_status(wptr);
//
//     if (status != 0) {
//       final err = monero.Wallet_errorString(wptr);
//       if (kDebugMode) print("err: $err");
//       throw WalletRestoreFromKeysException(message: err);
//     }
//
//     // monero.Wallet_setCacheAttribute(wptr, key: "cakewallet.seed", value: seed);
//     final wallet = MoneroWallet._(wptr, path);
//     wallet.store();
//     _openedWalletsByPath[path] = wallet;
//     return wallet;
//   }
//
//   static MoneroWallet loadWallet({
//     required String path,
//     required String password,
//     int nettype = 0,
//   }) {
//     MoneroWallet? wallet = _openedWalletsByPath[path];
//     if (wallet != null) {
//       return wallet;
//     }
//
//     try {
//       final wptr = monero.WalletManager_openWallet(
//         _wmPtr,
//         path: path,
//         password: password,
//       );
//       wallet = MoneroWallet._(wptr, path);
//       _openedWalletsByPath[path] = wallet;
//     } catch (e, s) {
//       if (kDebugMode) print("$e\n$s");
//       rethrow;
//     }
//
//     final status = monero.Wallet_status(wallet._getWalletPointer());
//     if (status != 0) {
//       final err = monero.Wallet_errorString(wallet._getWalletPointer());
//       if (kDebugMode) print("status: " + err);
//       throw WalletOpeningException(message: err);
//     }
//     return wallet;
//   }
//
//   // special check to see if wallet exists
//   static bool isWalletExist(String path) =>
//       monero.WalletManager_walletExists(_wmPtr, path);
//
//   // ===========================================================================
//   @override
//   int getRefreshFromBlockHeight() =>
//       monero.Wallet_getRefreshFromBlockHeight(_getWalletPointer());
//
//   @override
//   Future<bool> initConnection({
//     required String daemonAddress,
//     required bool trusted,
//     String? daemonUsername,
//     String? daemonPassword,
//     bool useSSL = false,
//     bool isLightWallet = false,
//     String? socksProxyAddress,
//   }) async {
//     if (kDebugMode)
//       print("init (initConnection()) node address: $daemonAddress");
//     final pointerAddress = _getWalletPointer().address;
//     await Isolate.run(() {
//       monero.Wallet_init(
//         Pointer.fromAddress(pointerAddress),
//         daemonAddress: daemonAddress,
//         daemonUsername: daemonUsername ?? '',
//         daemonPassword: daemonPassword ?? '',
//         proxyAddress: socksProxyAddress ?? '',
//         useSsl: useSSL,
//         lightWallet: isLightWallet,
//       );
//     });
//     final status = monero.Wallet_status(_getWalletPointer());
//     if (status != 0) {
//       final err = monero.Wallet_errorString(_getWalletPointer());
//       if (kDebugMode) print("init (initConnection()) status: $status");
//       if (kDebugMode) print("init (initConnection()) error: $err");
//       throw SetupWalletException(message: err);
//     }
//
//     // TODO error handling?
//     monero.Wallet_setTrustedDaemon(
//       _getWalletPointer(),
//       arg: trusted,
//     );
//
//     return status == 0;
//   }
//
//   // this probably does not do what you think it does
//   @override
//   Future<bool> createWatchOnly({
//     required String path,
//     required String password,
//     String language = "English",
//   }) async {
//     return await Isolate.run(
//       () => monero.Wallet_createWatchOnly(
//         _getWalletPointer(),
//         path: path,
//         password: password,
//         language: language,
//       ),
//     );
//   }
//
//   @override
//   void close() {
//     final pointerAddress = _getWalletPointer().address;
//     monero.Wallet_stop(Pointer.fromAddress(pointerAddress));
//     // _walletPointer = null;
//     // _openedWalletsByPath.remove(_path);
//   }
//
//   @override
//   int getHeightByDate(DateTime date) {
//     final nodeHeight = getNodeHeight();
//     final heightDistance = WalletApi.getHeightDistance(date);
//
//     if (nodeHeight <= 0) {
//       return 0;
//     }
//
//     return nodeHeight - heightDistance;
//   }
//
//   @override
//   Future<void> store() async {
//     final pointerAddress = _getWalletPointer().address;
//     await Isolate.run(() {
//       monero.Wallet_store(Pointer.fromAddress(pointerAddress));
//     });
//   }
//
//   @override
//   void setPassword(String password) {
//     monero.Wallet_setPassword(_getWalletPointer(), password: password);
//     final status = monero.Wallet_status(_getWalletPointer());
//     if (status == 0) {
//       throw Exception(monero.Wallet_errorString(_getWalletPointer()));
//     }
//   }
//
//   @override
//   String getSecretViewKey() => monero.Wallet_secretViewKey(_getWalletPointer());
//   @override
//   String getPublicViewKey() => monero.Wallet_publicViewKey(_getWalletPointer());
//   @override
//   String getSecretSpendKey() =>
//       monero.Wallet_secretSpendKey(_getWalletPointer());
//   @override
//   String getPublicSpendKey() =>
//       monero.Wallet_publicSpendKey(_getWalletPointer());
//   @override
//   String getSeed() {
//     // final cakePolySeed = monero.Wallet_getCacheAttribute(_getWalletPointer(),
//     //     key: "cakewallet.seed");
//     // if (cakePolySeed != "") {
//     //   return cakePolySeed;
//     // }
//     final polySeed =
//         monero.Wallet_getPolyseed(_getWalletPointer(), passphrase: '');
//     if (polySeed != "") {
//       return polySeed;
//     }
//     final legacy = monero.Wallet_seed(_getWalletPointer(), seedOffset: '');
//     return legacy;
//   }
//
//   @override
//   String getAddress({int accountIndex = 0, int addressIndex = 0}) =>
//       monero.Wallet_address(
//         _getWalletPointer(),
//         accountIndex: accountIndex,
//         addressIndex: addressIndex,
//       );
//
//   @override
//   int getFullBalance({int accountIndex = 0}) => monero.Wallet_balance(
//         _getWalletPointer(),
//         accountIndex: accountIndex,
//       );
//
//   @override
//   int getUnlockedBalance({int accountIndex = 0}) =>
//       monero.Wallet_unlockedBalance(
//         _getWalletPointer(),
//         accountIndex: accountIndex,
//       );
//
//   @override
//   int getCurrentHeight() => monero.Wallet_blockChainHeight(_getWalletPointer());
//   @override
//   int getNodeHeight() =>
//       monero.Wallet_daemonBlockChainHeight(_getWalletPointer());
//
//   @override
//   void startRefreshAsync() {
//     monero.Wallet_refreshAsync(_getWalletPointer());
//     monero.Wallet_startRefresh(_getWalletPointer());
//   }
//
//   @override
//   void setRecoveringFromSeed({required bool isRecovery}) =>
//       monero.Wallet_setRecoveringFromSeed(
//         _getWalletPointer(),
//         recoveringFromSeed: isRecovery,
//       );
//
//   @override
//   void startRescan(DateTime? fromDate, int? blockHeightOverride) {
//     final height = blockHeightOverride != null
//         ? blockHeightOverride!
//         : fromDate == null
//             ? null
//             : getHeightByDate(fromDate);
//     if (height != null) {
//       monero.Wallet_setRefreshFromBlockHeight(
//         _getWalletPointer(),
//         refresh_from_block_height: height,
//       );
//     }
//     monero.Wallet_rescanBlockchainAsync(_getWalletPointer());
//   }
//
//   void _refreshCoins(int pointerAddress) =>
//       monero.Coins_refresh(Pointer.fromAddress(pointerAddress));
//   @override
//   Future<void> refreshCoins() async {
//     _coinsPointer = monero.Wallet_coins(_getWalletPointer());
//     final pointerAddress = _coinsPointer!.address;
//     await compute(_refreshCoins, pointerAddress);
//   }
//
//   @override
//   Future<void> freezeCoin(String keyImage) async {
//     if (keyImage.isEmpty) {
//       throw Exception("Attempted freeze of empty keyImage.");
//     }
//
//     final count = monero.Coins_getAll_size(_coinsPointer!);
//
//     for (int i = 0; i < count; i++) {
//       if (keyImage ==
//           monero.CoinsInfo_keyImage(monero.Coins_coin(_coinsPointer!, i))) {
//         monero.Coins_setFrozen(_coinsPointer!, index: i);
//         return;
//       }
//     }
//
//     throw Exception(
//       "Can't freeze utxo for the gen keyImage if it cannot be found. *points at temple*",
//     );
//   }
//
//   @override
//   Future<void> thawCoin(String keyImage) async {
//     if (keyImage.isEmpty) {
//       throw Exception("Attempted thaw of empty keyImage.");
//     }
//
//     final count = monero.Coins_getAll_size(_coinsPointer!);
//
//     for (int i = 0; i < count; i++) {
//       if (keyImage ==
//           monero.CoinsInfo_keyImage(monero.Coins_coin(_coinsPointer!, i))) {
//         monero.Coins_thaw(_coinsPointer!, index: i);
//         return;
//       }
//     }
//
//     throw Exception(
//       "Can't thaw utxo for the gen keyImage if it cannot be found. *points at temple*",
//     );
//   }
//
//   @override
//   Future<List<UTXO>> getUTXOs({bool includeSpent = false}) async {
//     try {
//       await refreshCoins();
//       final count = monero.Coins_getAll_size(_coinsPointer!);
//
//       if (kDebugMode) {
//         print("monero::found_utxo_count=$count");
//       }
//
//       final List<UTXO> result = [];
//
//       for (int i = 0; i < count; i++) {
//         final coinPointer = monero.Coins_coin(_coinsPointer!, i);
//
//         final hash = monero.CoinsInfo_hash(coinPointer);
//
//         if (hash.isNotEmpty) {
//           final spent = monero.CoinsInfo_spent(coinPointer);
//
//           if (includeSpent || !spent) {
//             final utxo = UTXO(
//               address: monero.CoinsInfo_address(coinPointer),
//               hash: hash,
//               keyImage: monero.CoinsInfo_keyImage(coinPointer),
//               value: monero.CoinsInfo_amount(coinPointer),
//               isFrozen: monero.CoinsInfo_frozen(coinPointer),
//               isUnlocked: monero.CoinsInfo_unlocked(coinPointer),
//               vout: monero.CoinsInfo_internalOutputIndex(coinPointer),
//               spent: spent,
//               height: monero.CoinsInfo_blockHeight(coinPointer),
//               coinbase: monero.CoinsInfo_coinbase(coinPointer),
//             );
//
//             result.add(utxo);
//           }
//         } else {
//           if (kDebugMode) {
//             print("Found empty hash in monero utxo?!");
//           }
//         }
//       }
//
//       return result;
//     } catch (e, s) {
//       if (kDebugMode) {
//         print("$e\n$s");
//       }
//       rethrow;
//     }
//   }
//
//   @override
//   String getTxKey(String txId) {
//     return monero.Wallet_getTxKey(_getWalletPointer(), txid: txId);
//   }
//
//   void _refreshTransactions(int pointerAddress) =>
//       monero.TransactionHistory_refresh(
//         Pointer.fromAddress(
//           pointerAddress,
//         ),
//       );
//   @override
//   Future<void> refreshTransactions() async {
//     _transactionHistoryPointer = monero.Wallet_history(_getWalletPointer());
//     final pointerAddress = _transactionHistoryPointer!.address;
//     await compute(_refreshTransactions, pointerAddress);
//   }
//
//   @override
//   int transactionCount() =>
//       monero.TransactionHistory_count(_transactionHistoryPointer!);
//
//   @override
//   List<Transaction> getAllTransactions() {
//     final size = transactionCount();
//
//     return List.generate(
//       size,
//       (index) => Transaction(
//         txInfo: monero.TransactionHistory_transaction(
//           _transactionHistoryPointer!,
//           index: index,
//         ),
//         getTxKey: getTxKey,
//       ),
//     );
//   }
//
//   @override
//   Transaction getTransaction(String txId) {
//     return Transaction(
//       txInfo: monero.TransactionHistory_transactionById(
//         _transactionHistoryPointer!,
//         txid: txId,
//       ),
//       getTxKey: getTxKey,
//     );
//   }
//
//   @override
//   Future<int> estimateFee(TransactionPriority priority, int amount) async {
//     // FIXME: hardcoded value;
//     switch (priority) {
//       case TransactionPriority.normal:
//         return 24590000;
//       case TransactionPriority.low:
//         return 123050000;
//       case TransactionPriority.medium:
//         return 245029999;
//       case TransactionPriority.high:
//         return 614530000;
//       case TransactionPriority.last:
//         return 26021600000;
//     }
//   }
//
//   @override
//   Future<bool> isConnected() async {
//     // if (isRefreshPending) return connected;
//     // isRefreshPending = true;
//     final address = _getWalletPointer().address;
//     final result = await Isolate.run(() {
//       return monero.Wallet_connected(Pointer.fromAddress(address));
//     });
//
//     // connected = result == 1;
//     // isRefreshPending = false;
//     //
//     // return connected;
//
//     return result == 1;
//   }
//
//   // TODO check variance between this and createTransactionMultDest below
//   @override
//   Future<PendingTransactionDescription> createTransaction({
//     required String address,
//     required String paymentId,
//     required TransactionPriority priority,
//     String? amount,
//     int accountIndex = 0,
//     required List<String> preferredInputs,
//   }) async {
//     final amt = amount == null ? 0 : monero.Wallet_amountFromString(amount);
//
//     final addressPointer = address.toNativeUtf8();
//     final paymentIdAddress = paymentId.toNativeUtf8();
//     final preferredInputsPointer =
//         preferredInputs.join(monero.defaultSeparatorStr).toNativeUtf8();
//
//     final walletPointerAddress = _getWalletPointer().address;
//     final addressPointerAddress = addressPointer.address;
//     final paymentIdPointerAddress = paymentIdAddress.address;
//     final preferredInputsPointerAddress = preferredInputsPointer.address;
//     final separatorPointerAddress = monero.defaultSeparator.address;
//     final pendingTxPointer = Pointer<Void>.fromAddress(await Isolate.run(() {
//       final tx = monero_gen.MoneroC(DynamicLibrary.open(monero.libPath))
//           .MONERO_Wallet_createTransaction(
//         Pointer.fromAddress(walletPointerAddress),
//         Pointer.fromAddress(addressPointerAddress).cast(),
//         Pointer.fromAddress(paymentIdPointerAddress).cast(),
//         amt,
//         1,
//         priority.value,
//         accountIndex,
//         Pointer.fromAddress(preferredInputsPointerAddress).cast(),
//         Pointer.fromAddress(separatorPointerAddress),
//       );
//       return tx.address;
//     }));
//     calloc.free(addressPointer);
//     calloc.free(paymentIdAddress);
//     calloc.free(preferredInputsPointer);
//     final String? error = (() {
//       final status = monero.PendingTransaction_status(pendingTxPointer);
//       if (status == 0) {
//         return null;
//       }
//       return monero.PendingTransaction_errorString(pendingTxPointer);
//     })();
//
//     if (error != null) {
//       final message = error;
//       throw CreationTransactionException(message: message);
//     }
//
//     final rAmt = monero.PendingTransaction_amount(pendingTxPointer);
//     final rFee = monero.PendingTransaction_fee(pendingTxPointer);
//     final rHash = monero.PendingTransaction_txid(pendingTxPointer, '');
//     final rTxKey = rHash;
//
//     return PendingTransactionDescription(
//       amount: rAmt,
//       fee: rFee,
//       hash: rHash,
//       hex: '',
//       txKey: rTxKey,
//       pointerAddress: pendingTxPointer.address,
//     );
//   }
//
//   @override
//   Future<PendingTransactionDescription> createTransactionMultiDest({
//     required List<Recipient> outputs,
//     required String paymentId,
//     required TransactionPriority priority,
//     int accountIndex = 0,
//     required List<String> preferredInputs,
//   }) async {
//     final pendingTxPointer = monero.Wallet_createTransactionMultDest(
//       _getWalletPointer(),
//       dstAddr: outputs.map((e) => e.address!).toList(),
//       isSweepAll: false,
//       amounts:
//           outputs.map((e) => monero.Wallet_amountFromString(e.amount)).toList(),
//       mixinCount: 0,
//       pendingTransactionPriority: priority.value,
//       subaddr_account: accountIndex,
//     );
//     if (monero.PendingTransaction_status(pendingTxPointer) != 0) {
//       throw CreationTransactionException(
//           message: monero.PendingTransaction_errorString(pendingTxPointer));
//     }
//     return PendingTransactionDescription(
//       amount: monero.PendingTransaction_amount(pendingTxPointer),
//       fee: monero.PendingTransaction_fee(pendingTxPointer),
//       hash: monero.PendingTransaction_txid(pendingTxPointer, ''),
//       hex: monero.PendingTransaction_txid(pendingTxPointer, ''),
//       txKey: monero.PendingTransaction_txid(pendingTxPointer, ''),
//       pointerAddress: pendingTxPointer.address,
//     );
//   }
//
//   @override
//   void commitTransaction({
//     required PendingTransactionDescription pendingTransaction,
//   }) {
//     final transactionPointer = monero.PendingTransaction.fromAddress(
//       pendingTransaction.pointerAddress!,
//     );
//
//     monero.PendingTransaction_commit(transactionPointer,
//         filename: '', overwrite: false);
//
//     final String? error = (() {
//       final status =
//           monero.PendingTransaction_status(transactionPointer.cast());
//       if (status == 0) {
//         return null;
//       }
//       return monero.Wallet_errorString(_getWalletPointer());
//     })();
//
//     if (error != null) {
//       throw CreationTransactionException(message: error);
//     }
//   }
// }
