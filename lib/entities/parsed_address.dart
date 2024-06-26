// import 'package:flutter_libmonero/entities/openalias_record.dart';
// import 'package:flutter_libmonero/entities/yat_record.dart';
import 'package:flutter/material.dart';

enum ParseFrom { unstoppableDomains, openAlias, yatRecord, notParsed }

class ParsedAddress {
  ParsedAddress({
    this.addresses,
    this.name = '',
    this.description = '',
    this.parseFrom = ParseFrom.notParsed,
  });

  final List<String>? addresses;
  final String name;
  final String description;
  final ParseFrom parseFrom;

  // factory ParsedAddress.fetchEmojiAddress({
  //   @required List<YatRecord> addresses,
  //   @required String name,
  // }) {
  //   if (addresses?.isEmpty ?? true) {
  //     return ParsedAddress(addresses: [name], parseFrom: ParseFrom.yatRecord);
  //   }
  //   return ParsedAddress(
  //     addresses: addresses.map((e) => e.address).toList(),
  //     name: name,
  //     parseFrom: ParseFrom.yatRecord,
  //   );
  // }

  factory ParsedAddress.fetchUnstoppableDomainAddress({
    required String address,
    required String name,
  }) {
    if (address.isEmpty) {
      return ParsedAddress(addresses: [name]);
    }
    return ParsedAddress(
      addresses: [address],
      name: name,
      parseFrom: ParseFrom.unstoppableDomains,
    );
  }

  // factory ParsedAddress.fetchOpenAliasAddress(
  //     {@required OpenaliasRecord record, @required String name}) {
  //   final formattedName = OpenaliasRecord.formatDomainName(name);
  //   if (record == null || record.address.contains(formattedName)) {
  //     return ParsedAddress(addresses: [name]);
  //   }
  //   return ParsedAddress(
  //     addresses: [record.address],
  //     name: record.name,
  //     description: record.description,
  //     parseFrom: ParseFrom.openAlias,
  //   );
  // }
}
