import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_libmonero/flutter_libmonero.dart';

import 'models/account.dart';
import 'models/address.dart';

abstract class Wallet {
  // ===============================

  Timer? _autoSaveTimer;
  Duration autoSaveInterval = const Duration(minutes: 2);

  /// Will do nothing if wallet is closed.
  /// Auto saving will be cancelled if the wallet is closed.
  void startAutoSaving() {
    if (isClosed()) {
      return;
    }

    stopAutoSaving();
    _autoSaveTimer = Timer.periodic(autoSaveInterval, (_) async {
      if (isClosed()) {
        stopAutoSaving();
        return;
      }
      Logging.log?.d("Starting autosave");
      await save();
      Logging.log?.d("Finished autosave");
    });
  }

  void stopAutoSaving() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  // TODO: handle this differnetly
  Future<int> estimateFee(TransactionPriority priority, int amount) async {
    // FIXME: hardcoded value;
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

  // ===========================================================================
  // ======= Interface =========================================================

  @protected
  Future<void> refreshOutputs();

  @protected
  Future<void> refreshTransactions();

  @protected
  int transactionCount();

  @protected
  int syncHeight();

  int getBlockChainHeightByDate(DateTime date);

  Future<bool> connect({
    required String daemonAddress,
    required bool trusted,
    String? daemonUsername,
    String? daemonPassword,
    bool useSSL = false,
    bool isLightWallet = false,
    String? socksProxyAddress,
  });

  // this probably does not do what you think it does
  Future<bool> createWatchOnly({
    required String path,
    required String password,
    String language = "English",
  });

  bool isViewOnly();
  // void setDaemonConnection(DaemonConnection connection);
  // DaemonConnection getDaemonConnection();
  void setProxyUri(String proxyUri);
  Future<bool> isConnectedToDaemon();
  // Version getVersion();
  // NetworkType getNetworkType();
  String getPath();
  String getSeed();
  String getSeedLanguage();

  String getPrivateSpendKey();
  String getPrivateViewKey();
  String getPublicSpendKey();
  String getPublicViewKey();

  Address getAddress({int accountIndex = 0, int addressIndex = 0});

  int getDaemonHeight();
  // int getDaemonMaxPeerHeight();
  // int getApproximateChainHeight();
  // int getHeight();
  // int getHeightByDate(int year, int month, int day);

  int getSyncFromBlockHeight();
  void setStartSyncFromBlockHeight(int startHeight);
  void startSyncing({Duration interval = const Duration(seconds: 20)});
  void stopSyncing();

  Future<bool> rescanSpent();
  Future<bool> rescanBlockchain();

  int getBalance({int accountIndex = 0});
  int getUnlockedBalance({int accountIndex = 0});

  List<Account> getAccounts({bool includeSubaddresses = false, String? tag});
  Account getAccount(int accountIdx, {bool includeSubaddresses = false});
  void createAccount({String? label});

  void setAccountLabel(int accountIdx, String label);
  void setSubaddressLabel(int accountIdx, int addressIdx, String label);

  String getTxKey(String txid);
  Transaction getTx(String txId);
  List<Transaction> getTxs();
  // List<Transfer> getTransfers({int? accountIdx, int? subaddressIdx});
  Future<List<Output>> getOutputs({bool includeSpent = false});

  Future<bool> exportKeyImages({required String filename, bool all = false});
  Future<bool> importKeyImages({required String filename});

  Future<void> freezeOutput(String keyImage);
  Future<void> thawOutput(String keyImage);

  Future<PendingTransaction> createTx({
    required String address,
    required String paymentId,
    required TransactionPriority priority,
    String? amount,
    int accountIndex = 0,
    required List<String> preferredInputs,
  });

  Future<PendingTransaction> createTxMultiDest({
    required List<Recipient> outputs,
    required String paymentId,
    required TransactionPriority priority,
    int accountIndex = 0,
    required List<String> preferredInputs,
  });

  // List<PendingTransaction> createTxs(TxConfig config);
  // Tx sweepOutput(TxConfig config);
  // List<Tx> sweepUnlocked(TxConfig config);
  // List<Tx> sweepDust({bool relay = false});

  // String relayTxMeta(String txMetadata);
  // String relayTx(Tx tx);
  // List<String> submitTxs(String signedTxHex);

  Future<bool> commitTx(PendingTransaction tx);

  // Future<String> signMessage(
  //   String message,
  //   MessageSignatureType type,
  //   int accountIdx,
  //   int subaddressIdx,
  // );
  Future<String> signMessage(
    String message,
    String address,
  );
  Future<bool> verifyMessage(
    String message,
    String address,
    String signature,
  );

  // String getTxKey(String txId);
  // CheckTx checkTxKey(String txId, String txKey, String address);

  // String getTxProof(String txId, String address, {String? message});
  // CheckTx checkTxProof(
  //     String txId, String address, String message, String signature);
  // String getSpendProof(String txId, {String? message});
  // bool checkSpendProof(String txId, String message, String signature);
  // String getReserveProofWallet(String message);
  // String getReserveProofAccount(int accountIdx, int amount, String message);
  // CheckReserve checkReserveProof(
  //     String address, String message, String signature);

  // void setTxNotes(List<String> txHashes, List<String> notes);
  // void setTxNote(String txHash, String note);
  // List<String> getTxNotes(List<String> txHashes);
  // String getTxNote(String txHash);
  // List<AddressBookEntry> getAddressBookEntries({List<int>? entryIndices});
  // int addAddressBookEntry(String address, String description);
  // void editAddressBookEntry(int entryIdx, bool setAddress, String address,
  //     bool setDescription, String description);
  // void deleteAddressBookEntry(int entryIdx);
  // void tagAccounts(String tag, List<int> accountIndices);
  // void untagAccounts(List<int> accountIndices);
  // List<AccountTag> getAccountTags();
  // void setAccountTagLabel(String tag, String label);

  // TODO
  // String getPaymentUri(TxConfig request);

  // SendRequest parsePaymentUri(String uri);
  // String getAttribute(String key);
  // void setAttribute(String key, String val);

  // bool isMultisigImportNeeded();
  // bool isMultisig();
  // MultisigInfo getMultisigInfo();
  // String prepareMultisig();
  // String makeMultisig(
  //     List<String> multisigHexes, int threshold, String password);
  // MultisigInitResult exchangeMultisigKeys(
  //     List<String> multisigHexes, String password);
  // String exportMultisigHex();
  // int importMultisigHex(List<String> multisigHexes);
  // MultisigSignResult signMultisigTxHex(String multisigTxHex);
  // List<String> submitMultisig(String signedMultisigHex);

  // void moveTo(String path);
  String getPassword();
  void changePassword(String newPassword);
  Future<void> save();
  // Future<void> close({bool save = false});
  bool isClosed();
}
