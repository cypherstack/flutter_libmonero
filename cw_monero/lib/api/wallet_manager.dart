import 'dart:ffi';
import 'dart:isolate';

import 'package:cw_monero/api/exceptions/wallet_creation_exception.dart';
import 'package:cw_monero/api/exceptions/wallet_opening_exception.dart';
import 'package:cw_monero/api/exceptions/wallet_restore_from_keys_exception.dart';
import 'package:cw_monero/api/exceptions/wallet_restore_from_seed_exception.dart';
import 'package:cw_monero/api/wallet.dart';
import 'package:flutter/foundation.dart';
import 'package:monero/monero.dart' as monero;

abstract class XMRWalletManager {
  static monero.WalletManager? _wmPtr;
  static final monero.WalletManager wmPtr = Pointer.fromAddress((() {
    try {
      monero.printStarts = false;
      _wmPtr ??= monero.WalletManagerFactory_getWalletManager();
      if (kDebugMode) print("ptr: $_wmPtr");
    } catch (e) {
      if (kDebugMode) print(e);
    }
    return _wmPtr!.address;
  })());

  static XMRWallet createWalletSync({
    required String path,
    required String password,
    required String language,
    int nettype = 0,
  }) {
    final seed = monero.Wallet_createPolyseed();
    final wptr = monero.WalletManager_createWalletFromPolyseed(
      wmPtr,
      path: path,
      password: password,
      mnemonic: seed,
      seedOffset: '',
      newWallet: true,
      restoreHeight: 0,
      kdfRounds: 1,
    );

    // wptr = monero.WalletManager_createWallet(wmPtr, path: path, password: password, language: language, networkType: 0);

    final status = monero.Wallet_status(wptr);
    if (status != 0) {
      throw WalletCreationException(message: monero.Wallet_errorString(wptr));
    }

    final addr = wptr.address;
    Isolate.run(() {
      monero.Wallet_store(Pointer.fromAddress(addr), path: path);
    });

    final wallet = XMRWallet(walletPointer: wptr);
    openedWalletsByPath[path] = wallet;
    return wallet;

    // is the line below needed?
    // setupNodeSync(address: "node.moneroworld.com:18089");
  }

  static bool isWalletExistSync({required String path}) {
    return monero.WalletManager_walletExists(wmPtr, path);
  }

  static XMRWallet restoreWalletFromSeedSync(
      {required String path,
      required String password,
      required String seed,
      int nettype = 0,
      int restoreHeight = 0}) {
    final monero.wallet wptr;
    if (seed.split(' ').length == 25) {
      wptr = monero.WalletManager_recoveryWallet(
        wmPtr,
        path: path,
        password: password,
        mnemonic: seed,
        restoreHeight: restoreHeight,
        seedOffset: '',
        networkType: 0,
      );
    } else {
      wptr = monero.WalletManager_createWalletFromPolyseed(
        wmPtr,
        path: path,
        password: password,
        mnemonic: seed,
        seedOffset: '',
        newWallet: false,
        restoreHeight: restoreHeight,
        kdfRounds: 1,
      );
    }

    final status = monero.Wallet_status(wptr);

    if (status != 0) {
      final error = monero.Wallet_errorString(wptr);
      throw WalletRestoreFromSeedException(message: error);
    }

    final wallet = XMRWallet(walletPointer: wptr);
    openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static XMRWallet restoreWalletFromKeysSync(
      {required String path,
      required String password,
      required String language,
      required String address,
      required String viewKey,
      required String spendKey,
      int nettype = 0,
      int restoreHeight = 0}) {
    final wptr = monero.WalletManager_createWalletFromKeys(
      wmPtr,
      path: path,
      password: password,
      restoreHeight: restoreHeight,
      addressString: address,
      viewKeyString: viewKey,
      spendKeyString: spendKey,
      nettype: 0,
    );

    final status = monero.Wallet_status(wptr);
    if (status != 0) {
      throw WalletRestoreFromKeysException(
          message: monero.Wallet_errorString(wptr));
    }

    final wallet = XMRWallet(walletPointer: wptr);
    openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static XMRWallet restoreWalletFromSpendKeySync(
      {required String path,
      required String password,
      required String seed,
      required String language,
      required String spendKey,
      int nettype = 0,
      int restoreHeight = 0}) {
    // wptr = monero.WalletManager_createWalletFromKeys(
    //   wmPtr,
    //   path: path,
    //   password: password,
    //   restoreHeight: restoreHeight,
    //   addressString: '',
    //   spendKeyString: spendKey,
    //   viewKeyString: '',
    //   nettype: 0,
    // );

    final wptr = monero.WalletManager_createDeterministicWalletFromSpendKey(
      wmPtr,
      path: path,
      password: password,
      language: language,
      spendKeyString: spendKey,
      newWallet: true, // TODO(mrcyjanek): safe to remove
      restoreHeight: restoreHeight,
    );

    final status = monero.Wallet_status(wptr);

    if (status != 0) {
      final err = monero.Wallet_errorString(wptr);
      if (kDebugMode) print("err: $err");
      throw WalletRestoreFromKeysException(message: err);
    }

    monero.Wallet_setCacheAttribute(wptr, key: "cakewallet.seed", value: seed);
    final wallet = XMRWallet(walletPointer: wptr);
    wallet.storeSync();
    openedWalletsByPath[path] = wallet;
    return wallet;
  }

  static String _lastOpenedWallet = "";

  static Map<String, XMRWallet> openedWalletsByPath = {};

  static XMRWallet loadWallet({
    required String path,
    required String password,
    int nettype = 0,
  }) {
    XMRWallet? wallet = openedWalletsByPath[path];
    if (wallet != null) {
      return wallet;
    }

    try {
      final wptr = monero.WalletManager_openWallet(wmPtr,
          path: path, password: password);
      wallet = XMRWallet(walletPointer: wptr);
      openedWalletsByPath[path] = wallet;
      _lastOpenedWallet = path;
      // if (wptr == null || path != _lastOpenedWallet) {
      //   if (wptr != null) {
      //     final addr = wptr!.address;
      //     Isolate.run(() {
      //       monero.Wallet_store(Pointer.fromAddress(addr));
      //     });
      //   }
      //   wptr = monero.WalletManager_openWallet(wmPtr,
      //       path: path, password: password);
      //   openedWalletsByPath[path] = wptr!;
      //   _lastOpenedWallet = path;
      // }
    } catch (e, s) {
      if (kDebugMode) print("$e\n$s");
      rethrow;
    }

    final status = monero.Wallet_status(wallet.wptr);
    if (status != 0) {
      final err = monero.Wallet_errorString(wallet.wptr);
      if (kDebugMode) print("status: " + err);
      throw WalletOpeningException(message: err);
    }
    return wallet;
  }

  static XMRWallet _createWallet(Map<String, dynamic> args) {
    final path = args['path'] as String;
    final password = args['password'] as String;
    final language = args['language'] as String;

    return createWalletSync(path: path, password: password, language: language);
  }

  static XMRWallet _restoreFromSeed(Map<String, dynamic> args) {
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

  static XMRWallet _restoreFromKeys(Map<String, dynamic> args) {
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

  static XMRWallet _restoreFromSpendKey(Map<String, dynamic> args) {
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

  static Future<XMRWallet> _openWallet(Map<String, String> args) async =>
      loadWallet(
          path: args['path'] as String, password: args['password'] as String);

  static Future<bool> _isWalletExist(String path) async =>
      isWalletExistSync(path: path);

  static Future<XMRWallet> openWallet(
          {required String path,
          required String password,
          int nettype = 0}) async =>
      loadWallet(path: path, password: password, nettype: nettype);

  static Future<XMRWallet> openWalletAsync(Map<String, String> args) async =>
      _openWallet(args);

  static Future<XMRWallet> createWallet(
          {required String path,
          required String password,
          required String language,
          int nettype = 0}) async =>
      _createWallet({
        'path': path,
        'password': password,
        'language': language,
        'nettype': nettype
      });

  static Future<XMRWallet> restoreFromSeed(
          {required String path,
          required String password,
          required String seed,
          int nettype = 0,
          int restoreHeight = 0}) async =>
      _restoreFromSeed({
        'path': path,
        'password': password,
        'seed': seed,
        'nettype': nettype,
        'restoreHeight': restoreHeight
      });

  static Future<XMRWallet> restoreFromKeys(
          {required String path,
          required String password,
          required String language,
          required String address,
          required String viewKey,
          required String spendKey,
          int nettype = 0,
          int restoreHeight = 0}) async =>
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

  static Future<XMRWallet> restoreFromSpendKey(
          {required String path,
          required String password,
          required String seed,
          required String language,
          required String spendKey,
          int nettype = 0,
          int restoreHeight = 0}) async =>
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
