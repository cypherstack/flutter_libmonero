class Subaddress {
  Subaddress({
    required this.accountIndex,
    required this.index,
    required this.address,
    required this.label,
    required this.balance,
    required this.unlockedBalance,
    required this.numUnspentOutputs,
    required this.isUsed,
    required this.numBlocksToUnlock,
  });

  final int accountIndex;
  final int index;
  final String address;
  final String label;
  final BigInt balance;
  final BigInt unlockedBalance;
  final int numUnspentOutputs;
  final bool isUsed;
  final int numBlocksToUnlock;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln('Account index: $accountIndex')
      ..writeln('Subaddress index: $index')
      ..writeln('Address: $address')
      ..writeln('Label: $label')
      ..writeln('Balance: $balance')
      ..writeln('Unlocked balance: $unlockedBalance')
      ..writeln('Num unspent outputs: $numUnspentOutputs')
      ..writeln('Is used: $isUsed')
      ..writeln('Num blocks to unlock: $numBlocksToUnlock');
    return buffer.toString();
  }
}
