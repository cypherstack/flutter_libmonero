import 'dart:io';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:cw_core/monero_wallet_utils.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_wownero/api/exceptions/wallet_opening_exception.dart';
import 'package:cw_wownero/api/wallet_manager.dart';
import 'package:cw_wownero/wownero_wallet.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class WowneroNewWalletCredentials extends WalletCredentials {
  WowneroNewWalletCredentials(
      {String? name, String? password, this.language, int seedWordsLength = 14})
      : super(name: name, password: password);

  final String? language;
  final int seedWordsLength = 14;
}

class WowneroRestoreWalletFromSeedCredentials extends WalletCredentials {
  WowneroRestoreWalletFromSeedCredentials(
      {String? name, String? password, int? height, this.mnemonic})
      : super(name: name, password: password, height: height);

  final String? mnemonic;
}

class WowneroWalletLoadingException implements Exception {
  @override
  String toString() => 'Failure to load the wallet.';
}

class WowneroRestoreWalletFromKeysCredentials extends WalletCredentials {
  WowneroRestoreWalletFromKeysCredentials(
      {String? name,
      String? password,
      this.language,
      this.address,
      this.viewKey,
      this.spendKey,
      int? height})
      : super(name: name, password: password, height: height);

  final String? language;
  final String? address;
  final String? viewKey;
  final String? spendKey;
}

class WowneroWalletService extends WalletService<
    WowneroNewWalletCredentials,
    WowneroRestoreWalletFromSeedCredentials,
    WowneroRestoreWalletFromKeysCredentials> {
  WowneroWalletService(this.walletInfoSource);

  final Box<WalletInfo> walletInfoSource;

  static bool walletFilesExist(String path) =>
      !File(path).existsSync() && !File('$path.keys').existsSync();

  @override
  WalletType getType() => WalletType.wownero;

  @override
  Future<WowneroWallet> create(WowneroNewWalletCredentials credentials,
      {int seedWordsLength = 14}) async {
    try {
      final path =
          await pathForWallet(name: credentials.name!, type: getType());
      final wowWallet = await WOWWalletManager.createWallet(
        path: path,
        password: credentials.password!,
        language: credentials.language ??
            "English", /*seedWordsLength: seedWordsLength*/
      );
      final wallet = WowneroWallet(
        walletInfo: credentials.walletInfo!,
        wallet: wowWallet,
      );
      await wallet.init();

      return wallet;
    } catch (e) {
      // TODO: Implement Exception for wallet list service.
      if (kDebugMode) print('WowneroWalletsManager Error: ${e.toString()}');
      rethrow;
    }
  }

  @override
  Future<bool> isWalletExist(String name) async {
    try {
      final path = await pathForWallet(name: name, type: getType());
      return WOWWalletManager.isWalletExist(path: path);
    } catch (e) {
      // TODO: Implement Exception for wallet list service.
      if (kDebugMode) print('WowneroWalletsManager Error: $e');
      rethrow;
    }
  }

  @override
  Future<WowneroWallet> openWallet(String name, String password) async {
    try {
      final path = await pathForWallet(name: name, type: getType());

      if (walletFilesExist(path)) {
        await repairOldAndroidWallet(name);
      }

      final wowWallet = await WOWWalletManager.openWalletAsync(
          {'path': path, 'password': password});
      final walletInfo = walletInfoSource.values.firstWhereOrNull(
          (info) => info.id == WalletBase.idFor(name, getType()))!;
      final wallet = WowneroWallet(
        walletInfo: walletInfo,
        wallet: wowWallet,
      );
      final isValid = wallet.walletAddresses.validate();

      if (!isValid) {
        await restoreOrResetWalletFiles(name: name, type: WalletType.wownero);
        wallet.close();
        return openWallet(name, password);
      }

      await wallet.init();

      return wallet;
    } catch (e) {
      // TODO: Implement Exception for wallet list service.

      if ((e.toString().contains('bad_alloc') ||
              (e is WalletOpeningException &&
                  (e.message == 'std::bad_alloc' ||
                      e.message!.contains('bad_alloc')))) ||
          (e.toString().contains('does not correspond') ||
              (e is WalletOpeningException &&
                  e.message!.contains('does not correspond')))) {
        await restoreOrResetWalletFiles(name: name, type: WalletType.wownero);
        return openWallet(name, password);
      }

      rethrow;
    }
  }

  @override
  Future<void> remove(String wallet) async {
    final path = await pathForWalletDir(name: wallet, type: getType());
    final file = Directory(path);
    final isExist = file.existsSync();

    if (isExist) {
      await file.delete(recursive: true);
    }
  }

  @override
  Future<WowneroWallet> restoreFromKeys(
      WowneroRestoreWalletFromKeysCredentials credentials) async {
    try {
      final path =
          await pathForWallet(name: credentials.name!, type: getType());
      final wowWallet = await WOWWalletManager.restoreFromKeys(
          path: path,
          password: credentials.password!,
          language: credentials.language ?? "English",
          restoreHeight: credentials.height ?? 0,
          address: credentials.address!,
          viewKey: credentials.viewKey!,
          spendKey: credentials.spendKey!);
      final wallet = WowneroWallet(
        walletInfo: credentials.walletInfo!,
        wallet: wowWallet,
      );
      wallet.walletInfo.isRecovery = true;
      await wallet.init();

      return wallet;
    } catch (e) {
      // TODO: Implement Exception for wallet list service.
      print('WowneroWalletsManager Error: $e');
      rethrow;
    }
  }

  @override
  Future<WowneroWallet> restoreFromSeed(
      WowneroRestoreWalletFromSeedCredentials credentials) async {
    try {
      final path =
          await pathForWallet(name: credentials.name!, type: getType());
      final wowWallet = await WOWWalletManager.restoreFromSeed(
          path: path,
          password: credentials.password!,
          seed: credentials.mnemonic!,
          restoreHeight: credentials.height ?? 0);
      final wallet = WowneroWallet(
        walletInfo: credentials.walletInfo!,
        wallet: wowWallet,
      );
      wallet.walletInfo.isRecovery = true;

      final String seedString = credentials.mnemonic ?? '';
      final int seedWordsLength = seedString.split(' ').length;
      if (seedWordsLength == 14) {
        wallet.walletInfo.restoreHeight =
            wallet.getSeedHeight(credentials.mnemonic!);
      } else {
        wallet.walletInfo.restoreHeight = 0;
        // TODO use an alternative to wow_seed's get_seed_height
      }

      await wallet.init();
      return wallet;
    } catch (e) {
      // TODO: Implement Exception for wallet list service.
      print('WowneroWalletsManager Error: $e');
      rethrow;
    }
  }

  Future<void> repairOldAndroidWallet(String name) async {
    try {
      if (!Platform.isAndroid) {
        return;
      }

      final oldAndroidWalletDirPath =
          await outdatedAndroidPathForWalletDir(name: name);
      final dir = Directory(oldAndroidWalletDirPath);

      if (!dir.existsSync()) {
        return;
      }

      final newWalletDirPath =
          await pathForWalletDir(name: name, type: getType());

      dir.listSync().forEach((f) {
        final file = File(f.path);
        final name = f.path.split('/').last;
        final newPath = newWalletDirPath + '/$name';
        final newFile = File(newPath);

        if (!newFile.existsSync()) {
          newFile.createSync();
        }
        newFile.writeAsBytesSync(file.readAsBytesSync());
      });
    } catch (e) {
      print(e.toString());
    }
  }
}
