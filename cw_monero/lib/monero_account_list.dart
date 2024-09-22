import 'package:cw_core/account.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:monero/monero.dart' as monero;

import 'api/wallet.dart';

part 'monero_account_list.g.dart';

class MoneroAccountList = MoneroAccountListBase with _$MoneroAccountList;

abstract class MoneroAccountListBase with Store {
  MoneroAccountListBase(this.wallet)
      : accounts = ObservableList<Account>(),
        _isRefreshing = false,
        _isUpdating = false {
    refresh();
  }

  final XMRWallet wallet;

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
        // final balance = monero.SubaddressAccountRow_getUnlockedBalance(accountRow);

        return Account(
          id: monero.SubaddressAccountRow_getRowId(accountRow),
          label: monero.SubaddressAccountRow_getLabel(accountRow),
          // balance: moneroAmountToString(amount: monero.Wallet_amountFromString(balance)),
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
