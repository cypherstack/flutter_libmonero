import 'subaddress.dart';

class Account {
  Account({
    required this.index,
    required this.primaryAddress,
    required this.balance,
    required this.unlockedBalance,
    required this.tag,
    required List<Subaddress> subaddresses,
  }) : subaddresses = List.unmodifiable(subaddresses);

  final int index;
  final String primaryAddress;
  final BigInt balance;
  final BigInt unlockedBalance;
  final String tag;
  final List<Subaddress> subaddresses;

  @override
  String toString() {
    final sb = StringBuffer()
      ..writeln('Index: $index')
      ..writeln('Primary address: $primaryAddress')
      ..writeln('Balance: $balance')
      ..writeln('Unlocked balance: $unlockedBalance')
      ..writeln('Tag: $tag');
    if (subaddresses.isNotEmpty) {
      sb.writeln('Subaddresses:');
      for (int i = 0; i < subaddresses.length; i++) {
        sb.writeln('${i + 1}: ${subaddresses[i]}');
      }
    }
    return sb.toString();
  }
}
