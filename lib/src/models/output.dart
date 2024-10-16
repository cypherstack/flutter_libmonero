class Output {
  Output({
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
}
