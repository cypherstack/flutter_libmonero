import 'dart:io';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:stackwallet/hive/db.dart';

WalletType getType(String name) {
  // Find coin name for nettype (monero, moneroStageNet, moneroTestNet, etc) by calling the database for all wallet names and use the name param to find the coin ... Not a good solution, hacky, need to find better way to find the coin/nettype here
  final _names = DB.instance
      .get<dynamic>(boxName: DB.boxNameAllWalletsData, key: 'names') as Map?;

  Map<String, dynamic> names;
  if (_names == null) {
    names = {};
  } else {
    names = Map<String, dynamic>.from(_names);
  }

  if (names[name]['coin'] == 'moneroStageNet') {
    return WalletType.moneroStageNet;
  } else if (names[name]['coin'] == 'moneroTestNet') {
    return WalletType.moneroTestNet;
  } else {
    return WalletType.monero;
  }
}

String backupFileName(String originalPath) {
  final pathParts = originalPath.split('/');
  final newName = '#_${pathParts.last}';
  pathParts.removeLast();
  pathParts.add(newName);
  return pathParts.join('/');
}

Future<void> backupWalletFiles(String name) async {
  final path = await pathForWallet(name: name, type: getType(name));
  final cacheFile = File(path);
  final keysFile = File('$path.keys');
  final addressListFile = File('$path.address.txt');
  final newCacheFilePath = backupFileName(cacheFile.path);
  final newKeysFilePath = backupFileName(keysFile.path);
  final newAddressListFilePath = backupFileName(addressListFile.path);

  if (cacheFile.existsSync()) {
    await cacheFile.copy(newCacheFilePath);
  }

  if (keysFile.existsSync()) {
    await keysFile.copy(newKeysFilePath);
  }

  if (addressListFile.existsSync()) {
    await addressListFile.copy(newAddressListFilePath);
  }
}

Future<void> restoreWalletFiles(String name) async {
  final walletDirPath = await pathForWalletDir(name: name, type: getType(name));
  final cacheFilePath = '$walletDirPath/$name';
  final keysFilePath = '$walletDirPath/$name.keys';
  final addressListFilePath = '$walletDirPath/$name.address.txt';
  final backupCacheFile = File(backupFileName(cacheFilePath));
  final backupKeysFile = File(backupFileName(keysFilePath));
  final backupAddressListFile = File(backupFileName(addressListFilePath));

  if (backupCacheFile.existsSync()) {
    await backupCacheFile.copy(cacheFilePath);
  }

  if (backupKeysFile.existsSync()) {
    await backupKeysFile.copy(keysFilePath);
  }

  if (backupAddressListFile.existsSync()) {
    await backupAddressListFile.copy(addressListFilePath);
  }
}

Future<bool> backupWalletFilesExists(String name) async {
  final walletDirPath = await pathForWalletDir(name: name, type: getType(name));
  final cacheFilePath = '$walletDirPath/$name';
  final keysFilePath = '$walletDirPath/$name.keys';
  final addressListFilePath = '$walletDirPath/$name.address.txt';
  final backupCacheFile = File(backupFileName(cacheFilePath));
  final backupKeysFile = File(backupFileName(keysFilePath));
  final backupAddressListFile = File(backupFileName(addressListFilePath));

  return backupCacheFile.existsSync() &&
      backupKeysFile.existsSync() &&
      backupAddressListFile.existsSync();
}

Future<void> removeCache(String name) async {
  final path = await pathForWallet(name: name, type: getType(name));
  final cacheFile = File(path);

  if (cacheFile.existsSync()) {
    cacheFile.deleteSync();
  }
}

Future<void> restoreOrResetWalletFiles(String name) async {
  final backupsExists = await backupWalletFilesExists(name);

  if (backupsExists) {
    await restoreWalletFiles(name);
  }

  removeCache(name);
}
