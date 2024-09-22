import 'package:monero/monero.dart' as monero;

class Transaction {
  Transaction({
    required this.txInfo,
    required String Function(String txid) getTxKey,
  })  : displayLabel = monero.TransactionInfo_label(txInfo),
        hash = monero.TransactionInfo_hash(txInfo),
        timeStamp = DateTime.fromMillisecondsSinceEpoch(
          monero.TransactionInfo_timestamp(txInfo) * 1000,
        ),
        isSpend = monero.TransactionInfo_direction(txInfo) ==
            monero.TransactionInfo_Direction.Out,
        amount = monero.TransactionInfo_amount(txInfo),
        paymentId = monero.TransactionInfo_paymentId(txInfo),
        accountIndex = monero.TransactionInfo_subaddrAccount(txInfo),
        blockheight = monero.TransactionInfo_blockHeight(txInfo),
        confirmations = monero.TransactionInfo_confirmations(txInfo),
        fee = monero.TransactionInfo_fee(txInfo),
        description = monero.TransactionInfo_description(txInfo),
        key = getTxKey(monero.TransactionInfo_hash(txInfo));
  final String displayLabel;
  // String subaddressLabel = monero.Wallet_getSubaddressLabel(wptr!, accountIndex: 0, addressIndex: 0);
  // late final String address = monero.Wallet_address(
  //   wptr!,
  //   accountIndex: 0,
  //   addressIndex: 0,
  // );
  final String description;
  final int fee;
  final int confirmations;
  late final bool isPending = confirmations < 10;
  final int blockheight;
  final int addressIndex = 0;
  final int accountIndex;
  final String paymentId;
  final int amount;
  final bool isSpend;
  late DateTime timeStamp;
  late final bool isConfirmed = !isPending;
  final String hash;
  final String key;

  Map<String, dynamic> toJson() {
    return {
      "displayLabel": displayLabel,
      // "subaddressLabel": subaddressLabel,
      // "address": address,
      "description": description,
      "fee": fee,
      "confirmations": confirmations,
      "isPending": isPending,
      "blockheight": blockheight,
      "accountIndex": accountIndex,
      "addressIndex": addressIndex,
      "paymentId": paymentId,
      "amount": amount,
      "isSpend": isSpend,
      "timeStamp": timeStamp.toIso8601String(),
      "isConfirmed": isConfirmed,
      "hash": hash,
    };
  }

  // S finalubAddress? subAddress;
  // List<Transfer> transfers = [];
  // final int txIndex;
  final monero.TransactionInfo txInfo;
}
