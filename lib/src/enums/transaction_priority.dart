enum TransactionPriority {
  normal(0),
  low(1),
  medium(2),
  high(3),
  last(4);

  const TransactionPriority(this.value);
  final int value;
}
