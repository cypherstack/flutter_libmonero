import 'dart:async';

import 'package:flutter/services.dart';

export 'src/enums/monero_seed_type.dart';
export 'src/enums/transaction_priority.dart';
export 'src/enums/wownero_seed_type.dart';
export 'src/exceptions/creation_transaction_exception.dart';
export 'src/logging.dart';
export 'src/mixins/polling.dart';
export 'src/mnemonics/mnemonics.dart';
export 'src/models/output.dart';
export 'src/models/pending_transaction.dart';
export 'src/models/recipient.dart';
export 'src/models/transaction.dart';
export 'src/models/wallet_listener.dart';
export 'src/wallet.dart';
export 'src/wallets/monero_wallet.dart';
export 'src/wallets/wownero_wallet.dart';
export 'unused/previous/monero_wallet.dart';

class FlutterLibmonero {
  static const MethodChannel _channel =
      const MethodChannel('flutter_libmonero');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
