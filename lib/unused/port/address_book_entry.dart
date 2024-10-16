class AddressBookEntry {
  AddressBookEntry({
    required this.index,
    required this.address,
    required this.paymentId,
    required this.description,
  });
  final int index;
  final String address;
  final String paymentId;
  final String description;

  @override
  String toString() {
    final StringBuffer sb = StringBuffer();
    sb.writeln('Index: $index');
    sb.writeln('Address: $address');
    sb.writeln('Payment ID: $paymentId');
    sb.writeln('Description: $description');
    return sb.toString();
  }
}
