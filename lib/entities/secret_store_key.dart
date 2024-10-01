const moneroWalletPassword = "MONERO_WALLET_PASSWORD";

String generateStoreKeyFor({
  required String walletName,
}) {
  return moneroWalletPassword + "_" + walletName.toUpperCase();
}
