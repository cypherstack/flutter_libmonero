import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_type.dart';

abstract class WalletService<N extends WalletCredentials,
    RFS extends WalletCredentials, RFK extends WalletCredentials> {
  WalletType getType([int? nettype]);

  Future<WalletBase> create(N credentials, [int? nettype]);

  Future<WalletBase> restoreFromSeed(RFS credentials, [int? nettype]);

  Future<WalletBase> restoreFromKeys(RFK credentials, [int? nettype]);

  Future<WalletBase> openWallet(String name, String password, [int? nettype]);

  Future<bool> isWalletExist(String name, [int? nettype]);

  Future<void> remove(String wallet, [int? nettype]);
}
