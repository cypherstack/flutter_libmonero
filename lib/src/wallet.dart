import 'enums/transaction_priority.dart';
import 'models/output.dart';
import 'models/transaction.dart';
import 'models/utxo.dart';
import 'structs/pending_transaction.dart';

abstract interface class Wallet {
  static int getHeightDistance(DateTime date) {
    final distance =
        DateTime.now().millisecondsSinceEpoch - date.millisecondsSinceEpoch;
    final distanceSec = distance / 1000;
    final daysTmp = (distanceSec / 86400).round();
    final days = daysTmp < 1 ? 1 : daysTmp;

    return days * 720 + 2;
  }

  int getRefreshFromBlockHeight();

  Future<bool> initConnection({
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

  void close();

  int getHeightByDate(DateTime date);

  Future<void> store();

  void setPassword(String password);

  String getSecretViewKey();
  String getPublicViewKey();
  String getSecretSpendKey();
  String getPublicSpendKey();
  String getSeed();

  String getAddress({int accountIndex = 0, int addressIndex = 0});

  int getFullBalance({int accountIndex = 0});

  int getUnlockedBalance({int accountIndex = 0});

  int getCurrentHeight();
  int getNodeHeight();

  void startRefreshAsync();

  // TODO: used?
  void setRecoveringFromSeed({required bool isRecovery});

  void startRescan(DateTime? fromDate, int? blockHeightOverride);

  Future<void> refreshCoins();

  Future<void> freezeCoin(String keyImage);

  Future<void> thawCoin(String keyImage);

  Future<List<UTXO>> getUTXOs({bool includeSpent = false});

  String getTxKey(String txId);

  Future<void> refreshTransactions();

  int transactionCount();

  List<Transaction> getAllTransactions();

  Transaction getTransaction(String txId);

  Future<int> estimateFee(TransactionPriority priority, int amount);

  Future<bool> isConnected();

  Future<PendingTransactionDescription> createTransaction({
    required String address,
    required String paymentId,
    required TransactionPriority priority,
    String? amount,
    int accountIndex = 0,
    required List<String> preferredInputs,
  });

  Future<PendingTransactionDescription> createTransactionMultiDest({
    required List<Output> outputs,
    required String paymentId,
    required TransactionPriority priority,
    int accountIndex = 0,
    required List<String> preferredInputs,
  });

  void commitTransaction({
    required PendingTransactionDescription pendingTransaction,
  });
}
