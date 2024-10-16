// class AccountTag {
//   AccountTag({
//     required this.tag,
//     required this.label,
//     required this.accountIndices,
//   });
//
//   final String tag;
//   final String label;
//   final List<int> accountIndices;
//
//   @override
//   int get hashCode {
//     final prime = 31;
//     var result = 1;
//     result = prime * result + accountIndices.hashCode;
//     result = prime * result + label.hashCode;
//     result = prime * result + tag.hashCode;
//     return result;
//   }
//
//   @override
//   bool operator ==(Object obj) {
//     if (identical(this, obj)) return true;
//     if (obj is! AccountTag) return false;
//
//     return accountIndices == obj.accountIndices &&
//         label == obj.label &&
//         tag == obj.tag;
//   }
//
//   @override
//   String toString() {
//     return 'Tag: $tag, Label: $label, Account Indices: $accountIndices';
//   }
// }
