import 'package:monero/wownero.dart' as wownero;

class Transaction {
  Transaction({
    required this.txInfo,
    required String Function(String txid) getTxKey,
  })  : displayLabel = wownero.TransactionInfo_label(txInfo),
        hash = wownero.TransactionInfo_hash(txInfo),
        timeStamp = DateTime.fromMillisecondsSinceEpoch(
          wownero.TransactionInfo_timestamp(txInfo) * 1000,
        ),
        isSpend = wownero.TransactionInfo_direction(txInfo) ==
            wownero.TransactionInfo_Direction.Out,
        amount = wownero.TransactionInfo_amount(txInfo),
        paymentId = wownero.TransactionInfo_paymentId(txInfo),
        accountIndex = wownero.TransactionInfo_subaddrAccount(txInfo),
        blockheight = wownero.TransactionInfo_blockHeight(txInfo),
        confirmations = wownero.TransactionInfo_confirmations(txInfo),
        fee = wownero.TransactionInfo_fee(txInfo),
        description = wownero.TransactionInfo_description(txInfo),
        key = getTxKey(wownero.TransactionInfo_hash(txInfo));
  final String displayLabel;
  // String subaddressLabel = wownero.Wallet_getSubaddressLabel(wptr!,
  //     accountIndex: 0, addressIndex: 0);
  // late final String address = wownero.Wallet_address(
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
  final wownero.TransactionInfo txInfo;
}
