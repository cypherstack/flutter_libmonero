// class MultisigInitResult {
//   MultisigInitResult({
//     required this.address,
//     required this.multisigHex,
//   });
//   final String address;
//   final String multisigHex;
//
//   @override
//   String toString() {
//     return 'Address: $address, Multisig Hex: $multisigHex';
//   }
//
//   @override
//   int get hashCode => address.hashCode ^ multisigHex.hashCode;
//
//   @override
//   bool operator ==(Object other) {
//     if (identical(this, other)) return true;
//     if (other is! MultisigInitResult) return false;
//     return address == other.address && multisigHex == other.multisigHex;
//   }
// }
