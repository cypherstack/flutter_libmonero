import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_libmonero/entities/parsed_address.dart';
import 'package:flutter_libmonero/monero/monero.dart';
import 'package:intl/intl.dart';

import '../../wownero/wownero.dart';

const String cryptoNumberPattern = '0.0';

class Output {
  Output(this._wallet)
      : _cryptoNumberFormat = NumberFormat(cryptoNumberPattern) {
    reset();
    _setCryptoNumMaximumFractionDigits();
  }

  String? fiatAmount;

  String? cryptoAmount;

  String? address;

  String? note;

  bool? sendAll;

  ParsedAddress? parsedAddress;

  String? extractedAddress;

  bool get isParsedAddress =>
      parsedAddress!.parseFrom != ParseFrom.notParsed &&
      parsedAddress!.name.isNotEmpty;

  int get formattedCryptoAmount {
    int amount = 0;

    try {
      if (cryptoAmount?.isNotEmpty ?? false) {
        final _cryptoAmount = cryptoAmount!.replaceAll(',', '.');
        int _amount = 0;
        switch (walletType) {
          case WalletType.monero:
            _amount = monero.formatterMoneroParseAmount(amount: _cryptoAmount);
            break;
          case WalletType.wownero:
            _amount =
                wownero.formatterWowneroParseAmount(amount: _cryptoAmount);
            break;
          default:
            break;
        }

        if (_amount > 0) {
          amount = _amount;
        }
      }
    } catch (e) {
      amount = 0;
    }

    return amount;
  }

  double get estimatedFee {
    try {
      //TODO: should not be default fee, should be user chosen
      final fee = _wallet.calculateEstimatedFee(
          monero.getDefaultTransactionPriority(), formattedCryptoAmount);

      if (_wallet.type == WalletType.monero) {
        return monero.formatterMoneroAmountToDouble(amount: fee);
      }

      if (_wallet.type == WalletType.wownero) {
        return wownero.formatterWowneroAmountToDouble(amount: fee);
      }
    } catch (e) {
      if (kDebugMode) print(e.toString());
    }

    return 0;
  }

  WalletType? get walletType => _wallet.type;
  final WalletBase _wallet;
  final NumberFormat _cryptoNumberFormat;

  void setSendAll() => sendAll = true;

  void reset() {
    sendAll = false;
    cryptoAmount = '';
    fiatAmount = '';
    address = '';
    note = '';
    resetParsedAddress();
  }

  void resetParsedAddress() {
    extractedAddress = '';
    parsedAddress = ParsedAddress(addresses: []);
  }

  void setCryptoAmount(String amount) {
    cryptoAmount = amount;
  }

  void _setCryptoNumMaximumFractionDigits() {
    var maximumFractionDigits = 0;

    switch (_wallet.type) {
      case WalletType.monero:
        maximumFractionDigits = 12;
        break;
      case WalletType.bitcoin:
        maximumFractionDigits = 8;
        break;
      case WalletType.litecoin:
        maximumFractionDigits = 8;
        break;
      case WalletType.haven:
        maximumFractionDigits = 12;
        break;
      case WalletType.wownero:
        maximumFractionDigits = 12;
        break;
      default:
        break;
    }

    _cryptoNumberFormat.maximumFractionDigits = maximumFractionDigits;
  }
}
