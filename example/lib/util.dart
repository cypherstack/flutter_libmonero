import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> pathForWalletDir({
  required String name,
  required String type,
}) async {
  Directory root = await getApplicationDocumentsDirectory();
  if (Platform.isIOS) {
    root = (await getLibraryDirectory());
  }

  final walletsDir = Directory('${root.path}/wallets');
  final walletDire = Directory('${walletsDir.path}/$type/$name');

  if (!walletDire.existsSync()) {
    walletDire.createSync(recursive: true);
  }

  return walletDire.path;
}

Future<String> pathForWallet({
  required String name,
  required String type,
}) async =>
    await pathForWalletDir(name: name, type: type)
        .then((path) => path + '/$name');

void loggerPrint(Object? object) async {
  final utcTime = DateTime.now().toUtc().toString() + ": ";
  final defaultPrintLength = 1020 - utcTime.length;
  if (object == null || object.toString().length <= defaultPrintLength) {
    print("$utcTime$object");
  } else {
    final log = object.toString();
    int start = 0;
    int endIndex = defaultPrintLength;
    final logLength = log.length;
    int tmpLogLength = log.length;
    while (endIndex < logLength) {
      print(utcTime + log.substring(start, endIndex));
      endIndex += defaultPrintLength;
      start += defaultPrintLength;
      tmpLogLength -= defaultPrintLength;
    }
    if (tmpLogLength > 0) {
      print(utcTime + log.substring(start, logLength));
    }
  }
}
