// import 'lib_monero_error.dart';
//
// /// Enum representing the different Monero network types.
// enum MoneroNetworkType {
//   MAINNET(18, 19, 42),
//   TESTNET(53, 54, 63),
//   STAGENET(24, 25, 36);
//
//   final int primaryAddressCode;
//   final int integratedAddressCode;
//   final int subaddressCode;
//
//   const MoneroNetworkType(
//       this.primaryAddressCode, this.integratedAddressCode, this.subaddressCode);
//
//   int getPrimaryAddressCode() {
//     return primaryAddressCode;
//   }
//
//   int getIntegratedAddressCode() {
//     return integratedAddressCode;
//   }
//
//   int getSubaddressCode() {
//     return subaddressCode;
//   }
//
//   /// Parse a string to get the corresponding [MoneroNetworkType].
//   static MoneroNetworkType parse(String networkTypeStr) {
//     if (networkTypeStr.isEmpty) {
//       throw LibMoneroError("Cannot parse null or empty network type");
//     }
//     switch (networkTypeStr.toLowerCase()) {
//       case 'mainnet':
//         return MoneroNetworkType.MAINNET;
//       case 'testnet':
//         return MoneroNetworkType.TESTNET;
//       case 'stagenet':
//         return MoneroNetworkType.STAGENET;
//       default:
//         throw LibMoneroError("Invalid network type to parse: $networkTypeStr");
//     }
//   }
// }
