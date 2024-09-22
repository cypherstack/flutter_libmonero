import 'package:cw_core/amount_converter.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_wownero/api/structs/pending_transaction.dart';
import 'package:cw_wownero/api/wallet.dart';

class DoubleSpendException implements Exception {
  DoubleSpendException();

  @override
  String toString() =>
      'This transaction cannot be committed. This can be due to many reasons including the wallet not being synced, there is not enough WOW in your available balance, or previous transactions are not yet fully processed.';
}

class PendingWowneroTransaction with PendingTransaction {
  PendingWowneroTransaction(this.pendingTransactionDescription, this.wallet);

  final PendingTransactionDescription pendingTransactionDescription;

  final WOWWallet wallet;

  @override
  String get id => pendingTransactionDescription.hash!;

  @override
  String get amountFormatted => AmountConverter.amountIntToString(
      CryptoCurrency.wow, pendingTransactionDescription.amount!)!;

  @override
  String get feeFormatted => AmountConverter.amountIntToString(
      CryptoCurrency.wow, pendingTransactionDescription.fee!)!;

  @override
  Future<void> commit() async {
    try {
      wallet.commitTransactionFromPointerAddress(
          address: pendingTransactionDescription.pointerAddress!);
    } catch (e) {
      final message = e.toString();

      if (message.contains('Reason: double spend')) {
        throw DoubleSpendException();
      }

      rethrow;
    }
  }

  @override
  String get hex => throw UnimplementedError();
}
