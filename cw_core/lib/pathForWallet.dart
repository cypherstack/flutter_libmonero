import 'dart:io';

import 'package:cw_core/wallet_type.dart';
import 'package:path_provider/path_provider.dart';

abstract class FS {
  static Future<Directory> Function()? _applicationRootDirectory;
  static Future<Directory> Function() get applicationRootDirectory {
    if (_applicationRootDirectory == null) {
      throw Exception(
        "FS.setApplicationRootDirectoryFunction must be called on startup by "
        "any applications that uses this library!",
      );
    } else {
      return _applicationRootDirectory!;
    }
  }

  static void setApplicationRootDirectoryFunction(
    Future<Directory> Function() func,
  ) {
    if (_applicationRootDirectory != null) {
      _applicationRootDirectory = func;
    } else {
      throw Exception("FS.applicationRootDirectory function already set!");
    }
  }
}

Future<String> pathForWalletDir({
  required String name,
  required WalletType type,
}) async {
  final Directory root = await FS.applicationRootDirectory();

  final prefix = walletTypeToString(type).toLowerCase();
  final walletsDir = Directory('${root.path}/wallets');
  final walletDire = Directory('${walletsDir.path}/$prefix/$name');

  if (!walletDire.existsSync()) {
    walletDire.createSync(recursive: true);
  }

  return walletDire.path;
}

Future<String> pathForWallet({
  required String name,
  required WalletType type,
}) async =>
    await pathForWalletDir(name: name, type: type)
        .then((path) => path + '/$name');

Future<String> outdatedAndroidPathForWalletDir({String? name}) async {
  final Directory directory = await FS.applicationRootDirectory();

  final pathDir = directory.path + '/$name';

  return pathDir;
}

Future<bool> isDesktop() async {
  if (Platform.isIOS) {
    final Directory libraryPath = await getLibraryDirectory();
    if (!libraryPath.path.contains("/var/mobile/")) {
      return true;
    }
  }

  return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}
