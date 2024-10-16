import 'package:logger/logger.dart';

abstract class Logging {
  static Logger? log;

  static bool _useLogger = false;

  static bool get useLogger => _useLogger;

  static set useLogger(bool useLogger) {
    if (useLogger) {
      log = Logger(
        printer: PrefixPrinter(
          PrettyPrinter(
            printEmojis: false,
            methodCount: 0,
            excludeBox: {
              Level.info: true,
              Level.debug: true,
            },
          ),
        ),
      );
    } else {
      log = null;
    }
    _useLogger = useLogger;
  }
}
