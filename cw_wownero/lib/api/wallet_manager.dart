import 'dart:ffi';
import 'dart:isolate';

import 'package:cw_wownero/api/exceptions/wallet_creation_exception.dart';
import 'package:cw_wownero/api/exceptions/wallet_opening_exception.dart';
import 'package:cw_wownero/api/exceptions/wallet_restore_from_keys_exception.dart';
import 'package:cw_wownero/api/exceptions/wallet_restore_from_seed_exception.dart';
import 'package:cw_wownero/api/wallet.dart';
import 'package:flutter/foundation.dart';
import 'package:monero/wownero.dart' as wownero;

abstract class WOWWalletManager {
  static wownero.WalletManager? _wmPtr;
  static final wownero.WalletManager wmPtr = Pointer.fromAddress((() {
    wownero.WalletManagerFactory_setLogLevel(4);
    try {
      wownero.printStarts = false;
      _wmPtr ??= wownero.WalletManagerFactory_getWalletManager();
      wownero.WalletManagerFactory_setLogLevel(4);
      if (kDebugMode) print("ptr: $_wmPtr");
    } catch (e) {
      if (kDebugMode) print(e);
    }
    return _wmPtr!.address;
  })());

  static WOWWallet createWalletSync({
    required String path,
    required String password,
    required String language,
    int nettype = 0,
  }) {
    final wptr = wownero.WalletManager_createWallet(wmPtr,
        path: path,
        password: password,
        language: language,
        networkType: nettype);

    final status = wownero.Wallet_status(wptr);
    if (status != 0) {
      throw WalletCreationException(message: wownero.Wallet_errorString(wptr));
    }
    final addr = wptr.address;
    Isolate.run(() {
      wownero.Wallet_store(Pointer.fromAddress(addr), path: path);
    });
    final wallet = WOWWallet(walletPointer: wptr);
    openedWalletsByPath[path] = wallet;
    return wallet;
    // is the line below needed?
    // setupNodeSync(address: "node.wowneroworld.com:18089");
  }

  static bool isWalletExistSync({required String path}) {
    return wownero.WalletManager_walletExists(wmPtr, path);
  }

  static WOWWallet restoreWalletFromSeedSync({
    required String path,
    required String password,
    required String seed,
    int nettype = 0,
    int restoreHeight = 0,
  }) {
    wownero.wallet wptr;
    if (seed.split(" ").length == 14) {
      // typo on my end, language is seed.
      wptr = wownero.WOWNERO_deprecated_restore14WordSeed(
        path: path,
        password: password,
        language: seed,
        networkType: nettype,
      );

      wptr = wownero.WalletManager_openWallet(wmPtr,
          path: path, password: password);
    } else {
      wptr = wownero.WalletManager_recoveryWallet(
        wmPtr,
        path: path,
        password: password,
        mnemonic: seed,
        restoreHeight: restoreHeight,
        seedOffset: '',
        networkType: nettype,
      );
    }
    // if (kDebugMode) print("wptr: $wptr");
    final status = wownero.Wallet_status(wptr!);

    if (status != 0) {
      final error = wownero.Wallet_errorString(wptr!);
      throw WalletRestoreFromSeedException(message: error);
    }

    final wallet = WOWWallet(walletPointer: wptr);
    openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static WOWWallet restoreWalletFromKeysSync({
    required String path,
    required String password,
    required String language,
    required String address,
    required String viewKey,
    required String spendKey,
    int nettype = 0,
    int restoreHeight = 0,
  }) {
    final wptr = wownero.WalletManager_createWalletFromKeys(
      wmPtr,
      path: path,
      password: password,
      restoreHeight: restoreHeight,
      addressString: address,
      viewKeyString: viewKey,
      spendKeyString: spendKey,
      nettype: nettype,
    );

    final status = wownero.Wallet_status(wptr!);
    if (status != 0) {
      throw WalletRestoreFromKeysException(
          message: wownero.Wallet_errorString(wptr!));
    }

    final wallet = WOWWallet(walletPointer: wptr);
    openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static WOWWallet restoreWalletFromSpendKeySync({
    required String path,
    required String password,
    required String seed,
    required String language,
    required String spendKey,
    int nettype = 0,
    int restoreHeight = 0,
  }) {
    // wptr = wownero.WalletManager_createWalletFromKeys(
    //   wmPtr,
    //   path: path,
    //   password: password,
    //   restoreHeight: restoreHeight,
    //   addressString: '',
    //   spendKeyString: spendKey,
    //   viewKeyString: '',
    //   nettype: 0,
    // );

    final wptr = wownero.WalletManager_createDeterministicWalletFromSpendKey(
      wmPtr,
      path: path,
      password: password,
      language: language,
      spendKeyString: spendKey,
      newWallet: true, // TODO(mrcyjanek): safe to remove
      restoreHeight: restoreHeight,
    );

    final status = wownero.Wallet_status(wptr!);

    if (status != 0) {
      final err = wownero.Wallet_errorString(wptr!);
      if (kDebugMode) print("err: $err");
      throw WalletRestoreFromKeysException(message: err);
    }

    wownero.Wallet_setCacheAttribute(wptr!,
        key: "cakewallet.seed", value: seed);

    final wallet = WOWWallet(walletPointer: wptr);
    wallet.storeSync();
    openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static String _lastOpenedWallet = "";

  static Map<String, WOWWallet> openedWalletsByPath = {};

  static WOWWallet loadWallet(
      {required String path, required String password, int nettype = 0}) {
    WOWWallet? wallet = openedWalletsByPath[path];

    if (wallet != null) {
      return wallet;
    }

    try {
      final wptr = wownero.WalletManager_openWallet(wmPtr,
          path: path, password: password);
      wallet = WOWWallet(walletPointer: wptr);
      openedWalletsByPath[path] = wallet;
      _lastOpenedWallet = path;

      // if (wptr == null || path != _lastOpenedWallet) {
      //   if (wptr != null) {
      //     final addr = wptr!.address;
      //     Isolate.run(() {
      //       wownero.Wallet_store(Pointer.fromAddress(addr));
      //     });
      //   }
      //   wptr = wownero.WalletManager_openWallet(wmPtr,
      //       path: path, password: password);
      //   openedWalletsByPath[path] = wptr!;
      //   _lastOpenedWallet = path;
      // }
    } catch (e, s) {
      if (kDebugMode) print("$e\n$s");
      rethrow;
    }
    final status = wownero.Wallet_status(wallet.wptr!);
    if (status != 0) {
      final err = wownero.Wallet_errorString(wallet.wptr!);
      if (kDebugMode) print(err);
      throw WalletOpeningException(message: err);
    }

    return wallet;
  }

  static WOWWallet _createWallet(Map<String, dynamic> args) {
    final path = args['path'] as String;
    final password = args['password'] as String;
    final language = args['language'] as String;

    return createWalletSync(path: path, password: password, language: language);
  }

  static WOWWallet _restoreFromSeed(Map<String, dynamic> args) {
    final path = args['path'] as String;
    final password = args['password'] as String;
    final seed = args['seed'] as String;
    final restoreHeight = args['restoreHeight'] as int;

    return restoreWalletFromSeedSync(
        path: path,
        password: password,
        seed: seed,
        restoreHeight: restoreHeight);
  }

  static WOWWallet _restoreFromKeys(Map<String, dynamic> args) {
    final path = args['path'] as String;
    final password = args['password'] as String;
    final language = args['language'] as String;
    final restoreHeight = args['restoreHeight'] as int;
    final address = args['address'] as String;
    final viewKey = args['viewKey'] as String;
    final spendKey = args['spendKey'] as String;

    return restoreWalletFromKeysSync(
        path: path,
        password: password,
        language: language,
        restoreHeight: restoreHeight,
        address: address,
        viewKey: viewKey,
        spendKey: spendKey);
  }

  static WOWWallet _restoreFromSpendKey(Map<String, dynamic> args) {
    final path = args['path'] as String;
    final password = args['password'] as String;
    final seed = args['seed'] as String;
    final language = args['language'] as String;
    final spendKey = args['spendKey'] as String;
    final restoreHeight = args['restoreHeight'] as int;

    return restoreWalletFromSpendKeySync(
        path: path,
        password: password,
        seed: seed,
        language: language,
        restoreHeight: restoreHeight,
        spendKey: spendKey);
  }

  static Future<WOWWallet> _openWallet(Map<String, String> args) async =>
      loadWallet(
          path: args['path'] as String, password: args['password'] as String);

  static Future<bool> _isWalletExist(String path) async =>
      isWalletExistSync(path: path);

  static Future<WOWWallet> openWallet(
          {required String path,
          required String password,
          int nettype = 0}) async =>
      loadWallet(path: path, password: password, nettype: nettype);

  static Future<WOWWallet> openWalletAsync(Map<String, String> args) async =>
      _openWallet(args);

  static Future<WOWWallet> createWallet({
    required String path,
    required String password,
    required String language,
    int nettype = 0,
  }) async =>
      _createWallet({
        'path': path,
        'password': password,
        'language': language,
        'nettype': nettype
      });

  static Future<WOWWallet> restoreFromSeed({
    required String path,
    required String password,
    required String seed,
    int nettype = 0,
    int restoreHeight = 0,
  }) async =>
      _restoreFromSeed({
        'path': path,
        'password': password,
        'seed': seed,
        'nettype': nettype,
        'restoreHeight': restoreHeight
      });

  static Future<WOWWallet> restoreFromKeys({
    required String path,
    required String password,
    required String language,
    required String address,
    required String viewKey,
    required String spendKey,
    int nettype = 0,
    int restoreHeight = 0,
  }) async =>
      _restoreFromKeys({
        'path': path,
        'password': password,
        'language': language,
        'address': address,
        'viewKey': viewKey,
        'spendKey': spendKey,
        'nettype': nettype,
        'restoreHeight': restoreHeight
      });

  static Future<WOWWallet> restoreFromSpendKey({
    required String path,
    required String password,
    required String seed,
    required String language,
    required String spendKey,
    int nettype = 0,
    int restoreHeight = 0,
  }) async =>
      _restoreFromSpendKey({
        'path': path,
        'password': password,
        'seed': seed,
        'language': language,
        'spendKey': spendKey,
        'nettype': nettype,
        'restoreHeight': restoreHeight
      });

  static Future<bool> isWalletExist({required String path}) =>
      _isWalletExist(path);
}
