import 'package:cw_core/balance.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/currency_for_wallet_type.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/utxo.dart';
import 'package:cw_core/wallet_addresses.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';

abstract class WalletBase<
    BalanceType extends Balance,
    HistoryType extends TransactionHistoryBase,
    TransactionType extends TransactionInfo> {
  WalletBase(this.walletInfo);

  static String idFor(String name, WalletType type) =>
      walletTypeToString(type).toLowerCase() + '_' + name;

  WalletInfo walletInfo;

  WalletType? get type => walletInfo.type;

  CryptoCurrency? get currency => currencyForWalletType(type);

  String? get id => walletInfo.id;

  String? get name => walletInfo.name;

  //String get address;

  //set address(String address);

  ObservableMap<CryptoCurrency?, BalanceType>? get balance;

  SyncStatus? get syncStatus;

  set syncStatus(SyncStatus? status);

  String get seed;

  Object get keys;

  WalletAddresses get walletAddresses;

  HistoryType? transactionHistory;

  final List<UTXO> utxos = [];


  Future<void> freeze(String keyImage);
  Future<void> thaw(String keyImage);

  Future<void> updateUTXOs();

  Future<void> connectToNode(
      {required Node node, required String? socksProxyAddress});

  Future<void> startSync();

  Future<PendingTransaction> createTransaction(
    Object credentials, {
    required List<UTXO>? inputs,
  });

  int calculateEstimatedFee(TransactionPriority priority, int amount);

  // void fetchTransactionsAsync(
  //     void Function(TransactionType transaction) onTransactionLoaded,
  //     {void Function() onFinished});

  Future<Map<String, TransactionType>> fetchTransactions();

  Future<void> save();

  Future<void> rescan({int? height});

  void close();

  Future<void> changePassword(String password);
}
