// import 'dart:convert';
//
// import '../port/common/network_type.dart';
// import '../port/common/rpc_connection.dart';
//
// class MoneroWalletConfig {
//   MoneroWalletConfig({
//     required this.path,
//     required this.password,
//     required this.networkType,
//     required this.server,
//     required this.serverUsername,
//     required this.serverPassword,
//     required this.seed,
//     required this.seedOffset,
//     required this.primaryAddress,
//     required this.privateViewKey,
//     required this.privateSpendKey,
//     required this.restoreHeight,
//     required this.language,
//     this.saveCurrent,
//     this.accountLookahead,
//     this.subaddressLookahead,
//     this.keysData,
//     this.cacheData,
//     this.isMultisig,
//   });
//
//   final String path;
//   final String password;
//   final MoneroNetworkType networkType;
//   final MoneroRpcConnection server;
//   final String serverUsername;
//   final String serverPassword;
//   final String seed;
//   final String seedOffset;
//   final String primaryAddress;
//   final String privateViewKey;
//   final String privateSpendKey;
//   final int? restoreHeight;
//   final String language;
//   final bool? saveCurrent;
//   final int? accountLookahead;
//   final int? subaddressLookahead;
//   final List<int>? keysData;
//   final List<int>? cacheData;
//   final bool? isMultisig;
//
//   @override
//   String toString() {
//     return jsonEncode({
//       'path': path,
//       'password': password,
//       'networkType': networkType.toString(),
//       'server': server.toString(),
//       'serverUsername': serverUsername,
//       'serverPassword': serverPassword,
//       'seed': seed,
//       'seedOffset': seedOffset,
//       'primaryAddress': primaryAddress,
//       'privateViewKey': privateViewKey,
//       'privateSpendKey': privateSpendKey,
//       'restoreHeight': restoreHeight,
//       'language': language,
//       'saveCurrent': saveCurrent,
//       'accountLookahead': accountLookahead,
//       'subaddressLookahead': subaddressLookahead,
//       'keysData': keysData,
//       'cacheData': cacheData,
//       'isMultisig': isMultisig,
//     });
//   }
// }
