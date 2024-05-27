import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:io';

import 'package:cw_monero/api/account_list.dart';
import 'package:cw_monero/api/exceptions/setup_wallet_exception.dart';
import 'package:ffi/ffi.dart';
import 'package:monero/monero.dart' as monero;
import 'package:monero/src/generated_bindings_monero.g.dart' as monero_gen;

int getSyncingHeight() {
  // final height = monero.MONERO_cw_WalletListener_height(getWlptr());
  final h2 = monero.Wallet_blockChainHeight(wptr!);
  // print("height: $height / $h2");
  return h2;
}

bool isNeededToRefresh() {
  final ret = monero.MONERO_cw_WalletListener_isNeedToRefresh(getWlptr());
  monero.MONERO_cw_WalletListener_resetNeedToRefresh(getWlptr());
  return ret;
}

bool isNewTransactionExist() {
  final ret = monero.MONERO_cw_WalletListener_isNewTransactionExist(getWlptr());
  monero.MONERO_cw_WalletListener_resetIsNewTransactionExist(getWlptr());
  return ret;
}

String getFilename() => monero.Wallet_filename(wptr!);

String getSeed() {
  // monero.Wallet_setCacheAttribute(wptr!, key: "cakewallet.seed", value: seed);
  final cakepolyseed =
      monero.Wallet_getCacheAttribute(wptr!, key: "cakewallet.seed");
  if (cakepolyseed != "") {
    return cakepolyseed;
  }
  final polyseed = monero.Wallet_getPolyseed(wptr!, passphrase: '');
  if (polyseed != "") {
    return polyseed;
  }
  final legacy = monero.Wallet_seed(wptr!, seedOffset: '');
  return legacy;
}

String getAddress({int accountIndex = 0, int addressIndex = 1}) =>
    monero.Wallet_address(wptr!,
        accountIndex: accountIndex, addressIndex: addressIndex);

int getFullBalance({int accountIndex = 0}) =>
    monero.Wallet_balance(wptr!, accountIndex: accountIndex);

int getUnlockedBalance({int accountIndex = 0}) =>
    monero.Wallet_unlockedBalance(wptr!, accountIndex: accountIndex);

int getCurrentHeight() => monero.Wallet_blockChainHeight(wptr!);

int getNodeHeightSync() => monero.Wallet_daemonBlockChainHeight(wptr!);

bool isRefreshPending = false;
bool connected = false;

bool isConnectedSync() {
  if (isRefreshPending) return connected;
  isRefreshPending = true;
  final addr = wptr!.address;
  Isolate.run(() {
    monero.lib ??= monero_gen.MoneroC(DynamicLibrary.open(monero.libPath));
    return monero.lib!.MONERO_Wallet_connected(Pointer.fromAddress(addr));
  }).then((value) {
    connected = value == 1;
    isRefreshPending = false;
  });
  return connected;
}

Future<bool> setupNodeFuture(
    {required String address,
    String? login,
    String? password,
    bool useSSL = false,
    bool isLightWallet = false,
    String? socksProxyAddress}) async {
  print('''
{
  wptr!,
  daemonAddress: $address,
  useSsl: $useSSL,
  proxyAddress: $socksProxyAddress ?? '',
  daemonUsername: $login ?? '',
  daemonPassword: $password ?? ''
}
''');

  // Load the wallet as "offline" first
  // the reason being - wallet not initialized errors. we don't want crashes in here (or empty responses from functions).
  // monero.Wallet_init(wptr!, daemonAddress: '');
  print("init: $address");
  final waddr = wptr!.address;
  await Isolate.run(() {
    monero.Wallet_init(
      Pointer.fromAddress(waddr),
      daemonAddress: address,
      daemonUsername: login ?? '',
      daemonPassword: password ?? '',
      proxyAddress: socksProxyAddress ?? '',
      useSsl: useSSL,
      lightWallet: isLightWallet,
    );
  });
  int status = monero.Wallet_status(wptr!);
  if (status != 0) {
    final err = monero.Wallet_errorString(wptr!);
    print("init: $status");
    print("init: $err");
    throw SetupWalletException(message: err);
  }

  return status == 0;
}

void startRefreshSync() {
  monero.Wallet_refreshAsync(wptr!);
  monero.Wallet_startRefresh(wptr!);
}

Future<bool> connectToNode() async {
  return true;
}

void setRefreshFromBlockHeight({required int height}) =>
    monero.Wallet_setRefreshFromBlockHeight(wptr!,
        refresh_from_block_height: height);

void setRecoveringFromSeed({required bool isRecovery}) =>
    monero.Wallet_setRecoveringFromSeed(wptr!, recoveringFromSeed: isRecovery);

void storeSync() {
  final addr = wptr!.address;
  Isolate.run(() {
    monero.Wallet_store(Pointer.fromAddress(addr));
  });
}

void setPasswordSync(String password) {
  monero.Wallet_setPassword(wptr!, password: password);

  final status = monero.Wallet_status(wptr!);
  if (status == 0) {
    throw Exception(monero.Wallet_errorString(wptr!));
  }
}

void closeCurrentWallet() {
  monero.Wallet_stop(wptr!);
}

String getSecretViewKey() => monero.Wallet_secretViewKey(wptr!);

String getPublicViewKey() => monero.Wallet_publicViewKey(wptr!);

String getSecretSpendKey() => monero.Wallet_secretSpendKey(wptr!);

String getPublicSpendKey() => monero.Wallet_publicSpendKey(wptr!);

class SyncListener {
  SyncListener(this.onNewBlock, this.onNewTransaction)
      : _cachedBlockchainHeight = 0,
        _lastKnownBlockHeight = 0,
        _initialSyncHeight = 0;

  void Function(int, int, double) onNewBlock;
  void Function() onNewTransaction;

  Timer? _updateSyncInfoTimer;
  int _cachedBlockchainHeight;
  int _lastKnownBlockHeight;
  int _initialSyncHeight;

  Future<int> getNodeHeightOrUpdate(int baseHeight) async {
    if (_cachedBlockchainHeight < baseHeight || _cachedBlockchainHeight == 0) {
      _cachedBlockchainHeight = await getNodeHeight();
    }

    return _cachedBlockchainHeight;
  }

  void start() {
    _cachedBlockchainHeight = 0;
    _lastKnownBlockHeight = 0;
    _initialSyncHeight = 0;
    _updateSyncInfoTimer ??=
        Timer.periodic(Duration(milliseconds: 1200), (_) async {
      if (isNewTransactionExist()) {
        onNewTransaction();
      }

      var syncHeight = getSyncingHeight();

      if (syncHeight <= 0) {
        syncHeight = getCurrentHeight();
      }

      if (_initialSyncHeight <= 0) {
        _initialSyncHeight = syncHeight;
      }

      final bchHeight = await getNodeHeightOrUpdate(syncHeight);

      if (_lastKnownBlockHeight == syncHeight) {
        return;
      }

      _lastKnownBlockHeight = syncHeight;
      final track = bchHeight - _initialSyncHeight;
      final diff = track - (bchHeight - syncHeight);
      final ptc = diff <= 0 ? 0.0 : diff / track;
      final left = bchHeight - syncHeight;

      if (syncHeight < 0 || left < 0) {
        return;
      }

      // 1. Actual new height; 2. Blocks left to finish; 3. Progress in percents;
      onNewBlock.call(syncHeight, left, ptc);
    });
  }

  void stop() => _updateSyncInfoTimer?.cancel();
}

SyncListener setListeners(void Function(int, int, double) onNewBlock,
    void Function() onNewTransaction) {
  final listener = SyncListener(onNewBlock, onNewTransaction);
  // setListenerNative();
  return listener;
}

void onStartup() {}

void _storeSync(Object _) => storeSync();

Future<bool> _setupNode(Map<String, Object?> args) async {
  final address = args['address'] as String;
  final login = (args['login'] ?? '') as String;
  final password = (args['password'] ?? '') as String;
  final useSSL = args['useSSL'] as bool;
  final isLightWallet = args['isLightWallet'] as bool;
  final socksProxyAddress = (args['socksProxyAddress'] ?? '') as String;

  return setupNodeFuture(
      address: address,
      login: login,
      password: password,
      useSSL: useSSL,
      isLightWallet: isLightWallet,
      socksProxyAddress: socksProxyAddress);
}

bool _isConnected(Object _) => isConnectedSync();

int _getNodeHeight(Object _) => getNodeHeightSync();

void startRefresh() => startRefreshSync();

Future<void> setupNode(
        {required String address,
        String? login,
        String? password,
        bool useSSL = false,
        String? socksProxyAddress,
        bool isLightWallet = false}) async =>
    await _setupNode({
      'address': address,
      'login': login,
      'password': password,
      'useSSL': useSSL,
      'isLightWallet': isLightWallet,
      'socksProxyAddress': socksProxyAddress
    });

Future<void> store() async => _storeSync(0);

Future<bool> isConnected() async => _isConnected(0);

Future<int> getNodeHeight() async => _getNodeHeight(0);

void rescanBlockchainAsync() => monero.Wallet_rescanBlockchainAsync(wptr!);

String getSubaddressLabel(int accountIndex, int addressIndex) {
  return monero.Wallet_getSubaddressLabel(wptr!,
      accountIndex: accountIndex, addressIndex: addressIndex);
}

Future setTrustedDaemon(bool trusted) async =>
    monero.Wallet_setTrustedDaemon(wptr!, arg: trusted);

Future<bool> trustedDaemon() async => monero.Wallet_trustedDaemon(wptr!);

String signMessage(String message, {String address = ""}) {
  return monero.Wallet_signMessage(wptr!, message: message, address: address);
}
