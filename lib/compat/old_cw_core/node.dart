import 'package:hive/hive.dart';

import 'wallet_type.dart';

part 'node.g.dart';

Uri? createUriFromElectrumAddress(String? address) =>
    Uri.tryParse('tcp://$address');

@HiveType(typeId: Node.typeId)
class Node extends HiveObject {
  Node(
      {required String uri,
      required WalletType type,
      this.login,
      this.password,
      this.useSSL,
      this.trusted = false}) {
    uriRaw = uri;
    this.type = type;
  }

  Node.fromMap(Map map)
      : uriRaw = map['uri'] as String? ?? '',
        login = map['login'] as String?,
        password = map['password'] as String?,
        typeRaw = map['typeRaw'] as int?,
        useSSL = map['useSSL'] as bool?,
        trusted = map['trusted'] as bool? ?? false;

  static const typeId = 1;
  static const boxName = 'Nodes';

  @HiveField(0)
  String? uriRaw;

  @HiveField(1)
  String? login;

  @HiveField(2)
  String? password;

  @HiveField(3)
  int? typeRaw;

  @HiveField(4)
  bool? useSSL;

  @HiveField(5)
  bool trusted;

  bool get isSSL => useSSL ?? false;

  Uri? get uri {
    switch (type) {
      case WalletType.monero:
        return Uri.http(uriRaw!, '');
      case WalletType.bitcoin:
        return createUriFromElectrumAddress(uriRaw);
      case WalletType.litecoin:
        return createUriFromElectrumAddress(uriRaw);
      case WalletType.haven:
        return Uri.http(uriRaw!, '');
      case WalletType.wownero:
        return Uri.http(uriRaw!, '');
      default:
        return null;
    }
  }

  WalletType? get type => deserializeFromInt(typeRaw);

  set type(WalletType? type) => typeRaw = serializeToInt(type);
}
