import 'package:cw_core/account.dart';
import 'package:cw_wownero/api/wallet.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:monero/wownero.dart' as wownero;

part 'wownero_account_list.g.dart';

class WowneroAccountList = WowneroAccountListBase with _$WowneroAccountList;

abstract class WowneroAccountListBase with Store {
  WowneroAccountListBase(this.wallet)
      : accounts = ObservableList<Account>(),
        _isRefreshing = false,
        _isUpdating = false {
    refresh();
  }

  final WOWWallet wallet;

  @observable
  ObservableList<Account> accounts;
  bool _isRefreshing;
  bool _isUpdating;

  void update() async {
    if (_isUpdating) {
      return;
    }

    try {
      _isUpdating = true;
      refresh();
      final accounts = getAll();

      if (accounts.isNotEmpty) {
        this.accounts.clear();
        this.accounts.addAll(accounts);
      }

      _isUpdating = false;
    } catch (e) {
      _isUpdating = false;
      rethrow;
    }
  }

  List<Account> getAll() => wallet.getAllAccount().map((accountRow) {
        // final balance = wownero.SubaddressAccountRow_getUnlockedBalance(accountRow);

        return Account(
          id: wownero.SubaddressAccountRow_getRowId(accountRow),
          label: wownero.SubaddressAccountRow_getLabel(accountRow),
          // balance: wowneroAmountToString(amount: wownero.Wallet_amountFromString(balance)),
        );
      }).toList();

  Future addAccount({required String label}) async {
    await wallet.addAccount(label: label);
    update();
  }

  Future setLabelAccount(
      {required int accountIndex, required String label}) async {
    await wallet.setLabelForAccount(accountIndex: accountIndex, label: label);
    update();
  }

  void refresh() {
    if (_isRefreshing) {
      return;
    }

    try {
      _isRefreshing = true;
      wallet.refreshAccounts();
      _isRefreshing = false;
    } catch (e) {
      _isRefreshing = false;
      if (kDebugMode) print(e);
      rethrow;
    }
  }
}
