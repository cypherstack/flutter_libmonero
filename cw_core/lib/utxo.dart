class UTXO {
  UTXO({
    required this.address,
    required this.hash,
    required this.keyImage,
    required this.value,
    required this.isFrozen,
    required this.isUnlocked,
    required this.height,
    required this.vout,
    required this.spent,
    required this.coinbase,
  });

  final String address;
  final String hash;
  final int value;
  final String keyImage;
  final bool isFrozen;
  final bool isUnlocked;
  final int height;
  final int vout;
  final bool spent;
  final bool coinbase;

  @override
  String toString() {
    return 'UTXO(address: $address, hash: $hash, keyImage: $keyImage, value: $value, '
        'isFrozen: $isFrozen, isUnlocked: $isUnlocked, height: $height, '
        'vout: $vout, spent: $spent, coinbase: $coinbase)';
  }
}
