part of 'wownero.dart';

class CWWowneroAccountList extends WowneroAccountList {
  CWWowneroAccountList(this._wallet);
  final Object _wallet;

  @override
  @computed
  ObservableList<Account> get accounts {
    final wowneroWallet = _wallet as WowneroWallet;
    final accounts = wowneroWallet.walletAddresses.accountList.accounts
        .map((acc) => Account(id: acc.id, label: acc.label))
        .toList();
    return ObservableList<Account>.of(accounts);
  }

  @override
  void update(Object wallet) {
    final wowneroWallet = wallet as WowneroWallet;
    wowneroWallet.walletAddresses.accountList.update();
  }

  @override
  void refresh(Object wallet) {
    final wowneroWallet = wallet as WowneroWallet;
    wowneroWallet.walletAddresses.accountList.refresh();
  }

  @override
  List<Account> getAll(Object wallet) {
    final wowneroWallet = wallet as WowneroWallet;
    return wowneroWallet.walletAddresses.accountList
        .getAll()
        .map((acc) => Account(id: acc.id, label: acc.label))
        .toList();
  }

  @override
  Future<void> addAccount(Object wallet, {String? label}) async {
    final wowneroWallet = wallet as WowneroWallet;
    await wowneroWallet.walletAddresses.accountList
        .addAccount(label: label ?? "");
  }

  @override
  Future<void> setLabelAccount(Object wallet,
      {int? accountIndex, String? label}) async {
    final wowneroWallet = wallet as WowneroWallet;
    await wowneroWallet.walletAddresses.accountList
        .setLabelAccount(accountIndex: accountIndex ?? 0, label: label ?? "");
  }
}

class CWWowneroSubaddressList extends WowneroSubaddressList {
  CWWowneroSubaddressList(this._wallet);
  final Object _wallet;

  @override
  @computed
  ObservableList<Subaddress> get subaddresses {
    final wowneroWallet = _wallet as WowneroWallet;
    final subAddresses =
        wowneroWallet.walletAddresses.subaddressList.subaddresses!;
    return ObservableList<Subaddress>.of(subAddresses);
  }

  @override
  void update(Object wallet, {int? accountIndex}) {
    final wowneroWallet = wallet as WowneroWallet;
    wowneroWallet.walletAddresses.subaddressList
        .update(accountIndex: accountIndex ?? 0);
  }

  @override
  void refresh(Object wallet, {int? accountIndex}) {
    final wowneroWallet = wallet as WowneroWallet;
    wowneroWallet.walletAddresses.subaddressList
        .refresh(accountIndex: accountIndex ?? 0);
  }

  @override
  List<Subaddress> getAll(Object wallet) {
    final wowneroWallet = wallet as WowneroWallet;
    return wowneroWallet.walletAddresses.subaddressList.subaddresses!;
  }

  @override
  Future<void> addSubaddress(Object wallet,
      {int? accountIndex, String? label}) async {
    final wowneroWallet = wallet as WowneroWallet;
    await wowneroWallet.walletAddresses.subaddressList
        .addSubaddress(accountIndex: accountIndex ?? 0, label: label ?? "");
  }

  @override
  Future<void> setLabelSubaddress(Object wallet,
      {int? accountIndex, int? addressIndex, String? label}) async {
    final wowneroWallet = wallet as WowneroWallet;
    await wowneroWallet.walletAddresses.subaddressList.setLabelSubaddress(
        accountIndex: accountIndex ?? 0,
        addressIndex: addressIndex ?? 0,
        label: label ?? "");
  }
}

class CWWowneroWalletDetails extends WowneroWalletDetails {
  CWWowneroWalletDetails(this._wallet);
  final Object _wallet;

  @override
  @computed
  Account get account {
    final wowneroWallet = _wallet as WowneroWallet;
    final acc = wowneroWallet.walletAddresses.account!;
    return Account(id: acc.id, label: acc.label);
  }

  @override
  @computed
  WowneroBalance get balance {
    final wowneroWallet = _wallet as WowneroWallet;
    final balance = wowneroWallet.balance;
    var fullBalance = 0;
    var unlockedBalance = 0;
    // TODO: put actual values
    balance?.entries.forEach((element) {
      unlockedBalance += element.value.unlockedBalance;
      fullBalance += element.value.fullBalance;
    });
    return WowneroBalance(
        fullBalance: fullBalance, unlockedBalance: unlockedBalance);
    //return WowneroBalance(
    //	fullBalance: balance.fullBalance,
    //	unlockedBalance: balance.unlockedBalance);
  }
}

class CWWownero extends Wownero {
  @override
  WowneroAccountList getAccountList(Object wallet) {
    return CWWowneroAccountList(wallet);
  }

  @override
  WowneroSubaddressList getSubaddressList(Object wallet) {
    return CWWowneroSubaddressList(wallet);
  }

  @override
  TransactionHistoryBase? getTransactionHistory(Object wallet) {
    final wowneroWallet = wallet as WowneroWallet;
    return wowneroWallet.transactionHistory;
  }

  @override
  WowneroWalletDetails getWowneroWalletDetails(Object wallet) {
    return CWWowneroWalletDetails(wallet);
  }

  @override
  int getHeightByDate({DateTime? date}) {
    return getWowneroHeightByDate(date: date!);
  }

  @override
  TransactionPriority getDefaultTransactionPriority() {
    return MoneroTransactionPriority.slow;
  }

  @override
  TransactionPriority? deserializeMoneroTransactionPriority({int? raw}) {
    return MoneroTransactionPriority.deserialize(raw: raw);
  }

  @override
  List<TransactionPriority> getTransactionPriorities() {
    return MoneroTransactionPriority.all;
  }

  @override
  List<String> getWowneroWordList(String language, {int seedWordsLength = 14}) {
    switch (language.toLowerCase()) {
      case 'english':
        switch (seedWordsLength) {
          case 25:
            return EnglishMnemonics25.words;
          default:
            return EnglishMnemonics14.words;
        }
      default:
        switch (seedWordsLength) {
          case 25:
            return EnglishMnemonics25.words;
          default:
            return EnglishMnemonics14.words;
        }
    }
  }

  @override
  WalletCredentials createWowneroRestoreWalletFromKeysCredentials(
      {String? name,
      String? spendKey,
      String? viewKey,
      String? address,
      String? password,
      String? language,
      int? height}) {
    return WowneroRestoreWalletFromKeysCredentials(
        name: name,
        spendKey: spendKey,
        viewKey: viewKey,
        address: address,
        password: password,
        language: language,
        height: height);
  }

  @override
  WalletCredentials createWowneroRestoreWalletFromSeedCredentials(
      {String? name, String? password, int? height, String? mnemonic}) {
    return WowneroRestoreWalletFromSeedCredentials(
        name: name, password: password, height: height, mnemonic: mnemonic);
  }

  @override
  WalletCredentials createWowneroNewWalletCredentials(
      {String? name,
      String? password,
      String? language,
      int seedWordsLength = 14}) {
    return WowneroNewWalletCredentials(
        name: name,
        password: password,
        language: language,
        seedWordsLength: seedWordsLength);
  }

  @override
  Map<String, String?> getKeys(Object wallet) {
    final wowneroWallet = wallet as WowneroWallet;
    final keys = wowneroWallet.keys;
    return <String, String?>{
      'privateSpendKey': keys.privateSpendKey,
      'privateViewKey': keys.privateViewKey,
      'publicSpendKey': keys.publicSpendKey,
      'publicViewKey': keys.publicViewKey
    };
  }

  @override
  Object createWowneroTransactionCreationCredentials(
      {List<Output>? outputs, TransactionPriority? priority}) {
    return WowneroTransactionCreationCredentials(
        outputs: outputs!
            .map((out) => OutputInfo(
                fiatAmount: out.fiatAmount,
                cryptoAmount: out.cryptoAmount,
                address: out.address,
                note: out.note,
                sendAll: out.sendAll,
                extractedAddress: out.extractedAddress,
                isParsedAddress: out.isParsedAddress,
                formattedCryptoAmount: out.formattedCryptoAmount))
            .toList(),
        priority: priority as MoneroTransactionPriority);
  }

  @override
  String formatterWowneroAmountToString({int? amount}) {
    return wowneroAmountToString(amount: amount!);
  }

  @override
  double formatterWowneroAmountToDouble({int? amount}) {
    return wowneroAmountToDouble(amount: amount!);
  }

  @override
  int formatterWowneroParseAmount({String? amount}) {
    return wowneroParseAmount(amount: amount!);
  }

  @override
  Account getCurrentAccount(Object wallet) {
    final wowneroWallet = wallet as WowneroWallet;
    final acc = wowneroWallet.walletAddresses.account!;
    return Account(id: acc.id, label: acc.label);
  }

  @override
  void setCurrentAccount(Object wallet, int id, String label) {
    final wowneroWallet = wallet as WowneroWallet;
    wowneroWallet.walletAddresses.account =
        wownero_account.Account(id: id, label: label);
  }

  @override
  int? getTransactionInfoAccountId(TransactionInfo tx) {
    final wowneroTransactionInfo = tx as WowneroTransactionInfo;
    return wowneroTransactionInfo.accountIndex;
  }

  @override
  WalletService createWowneroWalletService(Box<WalletInfo> walletInfoSource) {
    return WowneroWalletService(walletInfoSource);
  }

  @override
  String getTransactionAddress(
      Object wallet, int accountIndex, int addressIndex) {
    final wowneroWallet = wallet as WowneroWallet;
    return wowneroWallet.getTransactionAddress(accountIndex, addressIndex);
  }

  @override
  String getSubaddressLabel(Object wallet, int accountIndex, int addressIndex) {
    final wowneroWallet = wallet as WowneroWallet;
    return wowneroWallet.getSubaddressLabel(accountIndex, addressIndex);
  }

  @override
  bool validateAddress(Object wallet, String address) {
    final wowneroWallet = wallet as WowneroWallet;
    return wownerodart.Wallet_addressValid(address, 0);
  }
}
