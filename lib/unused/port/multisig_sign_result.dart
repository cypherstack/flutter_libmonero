// class MultisigSignResult {
//   MultisigSignResult({
//     required this.signedMultisigTxHex,
//     required this.txHashes,
//   });
//   final String signedMultisigTxHex;
//   final List<String> txHashes;
//
//   @override
//   String toString() {
//     return 'Signed Multisig Tx Hex: $signedMultisigTxHex, Tx Hashes: $txHashes';
//   }
//
//   @override
//   int get hashCode => signedMultisigTxHex.hashCode ^ txHashes.hashCode;
//
//   @override
//   bool operator ==(Object other) {
//     if (identical(this, other)) return true;
//     if (other is! MultisigSignResult) return false;
//     return signedMultisigTxHex == other.signedMultisigTxHex &&
//         txHashes == other.txHashes;
//   }
// }
