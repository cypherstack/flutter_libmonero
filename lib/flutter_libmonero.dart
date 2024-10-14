import 'dart:async';

import 'package:flutter/services.dart';

export 'src/enums/monero_seed_type.dart';
export 'src/enums/transaction_priority.dart';
export 'src/enums/wownero_seed_type.dart';
export 'src/exceptions/creation_transaction_exception.dart';
export 'src/mnemonics/mnemonics.dart';
export 'src/models/output.dart';
export 'src/models/transaction.dart';
export 'src/models/utxo.dart';
export 'src/monero_wallet.dart';
export 'src/structs/pending_transaction.dart';
export 'src/wallet.dart';
export 'src/watcher.dart';
export 'src/wownero_wallet.dart';

class FlutterLibmonero {
  static const MethodChannel _channel =
      const MethodChannel('flutter_libmonero');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
