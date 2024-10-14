import 'dart:io';

Future<String> pathForWalletDir({
  required String name,
  required String type,
  required Directory appRoot,
}) async {
  final walletsDir = Directory('${appRoot.path}/wallets');
  final walletDire = Directory('${walletsDir.path}/$type/$name');

  if (!walletDire.existsSync()) {
    walletDire.createSync(recursive: true);
  }

  return walletDire.path;
}

Future<String> pathForWallet({
  required String name,
  required String type,
  required Directory appRoot,
}) async =>
    await pathForWalletDir(
      name: name,
      type: type,
      appRoot: appRoot,
    ).then((path) => path + '/$name');
