// class IntegratedAddress {
//   IntegratedAddress({
//     required this.standardAddress,
//     required this.paymentId,
//     required this.integratedAddress,
//   });
//
//   final String standardAddress;
//   final String paymentId;
//   final String integratedAddress;
//
//   @override
//   String toString() {
//     return integratedAddress;
//   }
//
//   @override
//   int get hashCode =>
//       standardAddress.hashCode ^
//       paymentId.hashCode ^
//       integratedAddress.hashCode;
//
//   @override
//   bool operator ==(Object other) {
//     if (identical(this, other)) return true;
//     if (other is! IntegratedAddress) return false;
//     return standardAddress == other.standardAddress &&
//         paymentId == other.paymentId &&
//         integratedAddress == other.integratedAddress;
//   }
// }
