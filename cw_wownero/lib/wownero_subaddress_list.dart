import 'package:cw_core/sub_address.dart';
import 'package:cw_wownero/api/wallet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';

part 'wownero_subaddress_list.g.dart';

class WowneroSubaddressList = WowneroSubaddressListBase
    with _$WowneroSubaddressList;

abstract class WowneroSubaddressListBase with Store {
  WowneroSubaddressListBase(this.wallet) {
    _isRefreshing = false;
    _isUpdating = false;
    subaddresses = ObservableList<Subaddress>();
  }

  final WOWWallet wallet;

  @observable
  ObservableList<Subaddress>? subaddresses;

  late bool _isRefreshing;
  late bool _isUpdating;

  void update({required int accountIndex}) {
    if (_isUpdating) {
      return;
    }

    try {
      _isUpdating = true;
      refresh(accountIndex: accountIndex);
      subaddresses!.clear();
      subaddresses!.addAll(getAll());
      _isUpdating = false;
    } catch (e) {
      _isUpdating = false;
      rethrow;
    }
  }

  List<Subaddress> getAll() {
    var subaddresses = wallet.getAllSubaddresses();

    if (subaddresses.length > 2) {
      final primary = subaddresses.first;
      final rest = subaddresses.sublist(1).reversed;
      subaddresses = [primary] + rest.toList();
    }

    return subaddresses.map((s) {
      final address = s.address;
      final label = s.label;
      final id = s.addressIndex;
      final hasDefaultAddressName =
          label.toLowerCase() == 'Primary account'.toLowerCase() ||
              label.toLowerCase() == 'Untitled account'.toLowerCase();
      final isPrimaryAddress = id == 0 && hasDefaultAddressName;
      return Subaddress(
          accountIndex: s.accountIndex,
          addressIndex: id,
          address: address,
          label: isPrimaryAddress
              ? 'Primary address'
              : hasDefaultAddressName
                  ? ''
                  : label);
    }).toList();
  }

  Future addSubaddress({
    required int accountIndex,
    required String label,
  }) async {
    await wallet.addSubaddress(accountIndex: accountIndex, label: label);
    update(accountIndex: accountIndex);
  }

  Future setLabelSubaddress({
    required int accountIndex,
    required int addressIndex,
    required String label,
  }) async {
    await wallet.setLabelForSubaddress(
      accountIndex: accountIndex,
      addressIndex: addressIndex,
      label: label,
    );
    update(accountIndex: accountIndex);
  }

  void refresh({required int accountIndex}) {
    if (_isRefreshing) {
      return;
    }

    try {
      _isRefreshing = true;
      wallet.refreshSubaddresses(accountIndex: accountIndex);
      _isRefreshing = false;
    } on PlatformException catch (e) {
      _isRefreshing = false;
      if (kDebugMode) print(e);
      rethrow;
    }
  }
}
