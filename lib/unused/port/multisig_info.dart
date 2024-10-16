// class MultisigInfo {
//   MultisigInfo({
//     required this.isMultisig,
//     this.isReady,
//     this.threshold,
//     this.numParticipants,
//   });
//
//   final bool isMultisig;
//   final bool? isReady;
//   final int? threshold;
//   final int? numParticipants;
//
//   @override
//   String toString() {
//     return 'isMultisig: $isMultisig, isReady: $isReady, threshold: $threshold, numParticipants: $numParticipants';
//   }
//
//   @override
//   int get hashCode =>
//       isMultisig.hashCode ^
//       isReady.hashCode ^
//       threshold.hashCode ^
//       numParticipants.hashCode;
//
//   @override
//   bool operator ==(Object other) {
//     if (identical(this, other)) return true;
//     if (other is! MultisigInfo) return false;
//     return isMultisig == other.isMultisig &&
//         isReady == other.isReady &&
//         threshold == other.threshold &&
//         numParticipants == other.numParticipants;
//   }
// }
