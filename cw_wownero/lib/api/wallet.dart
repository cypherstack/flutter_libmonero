import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:cw_wownero/api/account_list.dart';
import 'package:cw_wownero/api/exceptions/setup_wallet_exception.dart';
import 'package:monero/wownero.dart' as wownero;
import 'package:ffi/ffi.dart';
import 'package:monero/src/generated_bindings_wownero.g.dart' as wownero_gen;

int getSyncingHeight() {
  // final height = wownero.WOWNERO_cw_WalletListener_height(getWlptr());
  final h2 = wownero.Wallet_blockChainHeight(wptr!);
  // print("height: $height / $h2");
  return h2;
}

bool isNeededToRefresh() {
  final ret = wownero.WOWNERO_cw_WalletListener_isNeedToRefresh(getWlptr());
  wownero.WOWNERO_cw_WalletListener_resetNeedToRefresh(getWlptr());
  return ret;
}

bool isNewTransactionExist() {
  final ret =
      wownero.WOWNERO_cw_WalletListener_isNewTransactionExist(getWlptr());
  wownero.WOWNERO_cw_WalletListener_resetIsNewTransactionExist(getWlptr());
  return ret;
}

String getFilename() => wownero.Wallet_filename(wptr!);

String getSeed() {
  // wownero.Wallet_setCacheAttribute(wptr!, key: "cakewallet.seed", value: seed);
  final cakepolyseed =
      wownero.Wallet_getCacheAttribute(wptr!, key: "cakewallet.seed");
  if (cakepolyseed != "") {
    return cakepolyseed;
  }
  final polyseed = wownero.Wallet_getPolyseed(wptr!, passphrase: '');
  if (polyseed != "") {
    return polyseed;
  }
  final legacy = wownero.Wallet_seed(wptr!, seedOffset: '');
  return legacy;
}

String getAddress({int accountIndex = 0, int addressIndex = 1}) =>
    wownero.Wallet_address(wptr!,
        accountIndex: accountIndex, addressIndex: addressIndex);

bool addressValid(String address) => wownero.Wallet_addressValid(address, 0);

int getFullBalance({int accountIndex = 0}) =>
    wownero.Wallet_balance(wptr!, accountIndex: accountIndex);

int getUnlockedBalance({int accountIndex = 0}) =>
    wownero.Wallet_unlockedBalance(wptr!, accountIndex: accountIndex);

int getCurrentHeight() => wownero.Wallet_blockChainHeight(wptr!);

int getNodeHeightSync() =>
    wownero.WOWNERO_cw_WalletListener_height(getWlptr()!);

bool isRefreshPending = false;
bool connected = false;

bool isConnectedSync() {
  if (isRefreshPending) return connected;
  isRefreshPending = true;
  final addr = wptr!.address;
  Isolate.run(() {
    wownero.lib ??= wownero_gen.WowneroC(DynamicLibrary.open(wownero.libPath));
    return wownero.lib!.WOWNERO_Wallet_connected(Pointer.fromAddress(addr));
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
  // wownero.Wallet_init(wptr!, daemonAddress: '');
  print("init: $address");
  final waddr = wptr!.address;
  final address_ = address.toNativeUtf8().address;
  final username_ = (login ?? '').toNativeUtf8().address;
  final password_ = (password ?? '').toNativeUtf8().address;
  final socksProxyAddress_ = (socksProxyAddress ?? '').toNativeUtf8().address;
  await Isolate.run(() async {
    wownero.lib ??= wownero_gen.WowneroC(DynamicLibrary.open(wownero.libPath));
    wownero.lib!.WOWNERO_Wallet_init(
      Pointer.fromAddress(waddr),
      Pointer.fromAddress(address_).cast(),
      0,
      Pointer.fromAddress(username_).cast(),
      Pointer.fromAddress(password_).cast(),
      useSSL,
      isLightWallet,
      Pointer.fromAddress(socksProxyAddress_).cast(),
    );
  });
  calloc.free(Pointer.fromAddress(address_));
  calloc.free(Pointer.fromAddress(username_));
  calloc.free(Pointer.fromAddress(password_));
  calloc.free(Pointer.fromAddress(socksProxyAddress_));
  final status = wownero.Wallet_status(wptr!);
  if (status != 0) {
    final err = wownero.Wallet_errorString(wptr!);
    print("init: $status");
    print("init: $err");
    throw SetupWalletException(message: err);
  }
  wownero.Wallet_init3(wptr!,
      argv0: "stack_wallet",
      defaultLogBaseName: "",
      logPath: "/dev/shm/wow.log",
      console: true);

  return status == 0;
}

void startRefreshSync() {
  wownero.Wallet_refreshAsync(wptr!);
  wownero.Wallet_startRefresh(wptr!);
}

Future<bool> connectToNode() async {
  return true;
}

void setRefreshFromBlockHeight({required int height}) =>
    wownero.Wallet_setRefreshFromBlockHeight(wptr!,
        refresh_from_block_height: height);

void setRecoveringFromSeed({required bool isRecovery}) =>
    wownero.Wallet_setRecoveringFromSeed(wptr!, recoveringFromSeed: isRecovery);

void storeSync() {
  wownero.Wallet_store(wptr!);
}

void setPasswordSync(String password) {
  wownero.Wallet_setPassword(wptr!, password: password);

  final status = wownero.Wallet_status(wptr!);
  if (status == 0) {
    throw Exception(wownero.Wallet_errorString(wptr!));
  }
}

void closeCurrentWallet() {
  wownero.Wallet_stop(wptr!);
}

String getSecretViewKey() => wownero.Wallet_secretViewKey(wptr!);

String getPublicViewKey() => wownero.Wallet_publicViewKey(wptr!);

String getSecretSpendKey() => wownero.Wallet_secretSpendKey(wptr!);

String getPublicSpendKey() => wownero.Wallet_publicSpendKey(wptr!);

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

void rescanBlockchainAsync() => wownero.Wallet_rescanBlockchainAsync(wptr!);

String getSubaddressLabel(int accountIndex, int addressIndex) {
  return wownero.Wallet_getSubaddressLabel(wptr!,
      accountIndex: accountIndex, addressIndex: addressIndex);
}

Future setTrustedDaemon(bool trusted) async =>
    wownero.Wallet_setTrustedDaemon(wptr!, arg: trusted);

Future<bool> trustedDaemon() async => wownero.Wallet_trustedDaemon(wptr!);

String signMessage(String message, {String address = ""}) {
  return wownero.Wallet_signMessage(wptr!, message: message, address: address);
}
