import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_monero/monero_wallet_service.dart';
import 'package:cw_wownero/wownero_wallet_service.dart';
import 'package:flutter_libmonero/core/key_service.dart';
import 'package:stack_wallet_backup/generate_password.dart';

class WalletCreationService {
  WalletCreationService({
    required this.secureStorage,
    required this.keyService,
    required this.type,
    required WalletService walletService,
  })  : _service = walletService,
        assert(
          walletService is MoneroWalletService && type == WalletType.monero ||
              walletService is WowneroWalletService &&
                  type == WalletType.wownero,
        );

  final WalletType type;
  final dynamic secureStorage;
  final KeyService keyService;
  final WalletService _service;

  Future<WalletBase> create(WalletCredentials credentials) async {
    final password = generatePassword();
    credentials.password = password;
    await keyService.saveWalletPassword(
      password: password,
      walletName: credentials.name,
    );
    return await _service.create(credentials);
  }

  Future<WalletBase> restoreFromKeys(WalletCredentials credentials) async {
    final password = generatePassword();
    credentials.password = password;
    await keyService.saveWalletPassword(
      password: password,
      walletName: credentials.name,
    );
    return await _service.restoreFromKeys(credentials);
  }

  Future<WalletBase> restoreFromSeed(WalletCredentials credentials) async {
    final password = generatePassword();
    credentials.password = password;
    await keyService.saveWalletPassword(
      password: password,
      walletName: credentials.name,
    );
    return await _service.restoreFromSeed(credentials);
  }
}
