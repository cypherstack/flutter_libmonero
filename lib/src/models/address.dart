class Address {
  Address({
    required this.value,
    required this.account,
    required this.index,
  });

  final String value;
  final int account;
  final int index;

  @override
  String toString() {
    return "Address { value: $value, account: $account, index: $index }";
  }
}
