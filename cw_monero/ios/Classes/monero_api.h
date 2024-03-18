#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>
#include "CwWalletListener.h"

// Define a macro for exporting functions on Windows.
#if defined(_WIN32) || defined(_WIN64) || defined(__MINGW32___) || defined(__declspec) || defined(BUILDING_FOR_WINDOWS)
#define DLL_EXPORT __declspec(dllexport)
#else
#define DLL_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

DLL_EXPORT void change_current_wallet(Monero::Wallet *wallet);
DLL_EXPORT Monero::Wallet *get_current_wallet();
DLL_EXPORT bool create_wallet(char *path, char *password, char *language, int32_t networkType, char *error);
DLL_EXPORT bool restore_wallet_from_seed(char *path, char *password, char *seed, int32_t networkType, uint64_t restoreHeight, char *error);
DLL_EXPORT bool restore_wallet_from_keys(char *path, char *password, char *language, char *address, char *viewKey, char *spendKey, int32_t networkType, uint64_t restoreHeight, char *error);
DLL_EXPORT bool load_wallet(char *path, char *password, int32_t nettype);
DLL_EXPORT char *error_string() {
DLL_EXPORT bool is_wallet_exist(char *path);
DLL_EXPORT void close_current_wallet();
DLL_EXPORT char *get_filename();
DLL_EXPORT char *secret_view_key();
DLL_EXPORT char *public_view_key();
DLL_EXPORT char *secret_spend_key();
DLL_EXPORT char *public_spend_key();
DLL_EXPORT char *get_address(uint32_t account_index, uint32_t address_index);
DLL_EXPORT const char *seed();
DLL_EXPORT uint64_t get_full_balance(uint32_t account_index);
DLL_EXPORT uint64_t get_unlocked_balance(uint32_t account_index);
DLL_EXPORT uint64_t get_current_height();
DLL_EXPORT uint64_t get_node_height();
DLL_EXPORT bool connect_to_node(char *error);
DLL_EXPORT bool setup_node(char *address, char *login, char *password, bool use_ssl, bool is_light_wallet, char *error);
DLL_EXPORT bool is_connected();
DLL_EXPORT void start_refresh();
DLL_EXPORT void set_refresh_from_block_height(uint64_t height);
DLL_EXPORT void set_recovering_from_seed(bool is_recovery);
DLL_EXPORT void store(char *path);
DLL_EXPORT bool set_password(char *password, Utf8Box &error) {
DLL_EXPORT bool transaction_create(char *address, char *payment_id, char *amount,
DLL_EXPORT bool transaction_create_mult_dest(char **addresses, char *payment_id, char **amounts, uint32_t size,
DLL_EXPORT bool transaction_commit(PendingTransactionRaw *transaction, Utf8Box &error);
DLL_EXPORT uint64_t get_node_height_or_update(uint64_t base_eight);
DLL_EXPORT uint64_t get_syncing_height();
DLL_EXPORT uint64_t is_needed_to_refresh();
DLL_EXPORT uint8_t is_new_transaction_exist();
DLL_EXPORT void set_listener();
DLL_EXPORT int64_t *subaddrress_get_all();
DLL_EXPORT int32_t subaddrress_size();
DLL_EXPORT void subaddress_add_row(uint32_t accountIndex, char *label);
DLL_EXPORT void subaddress_set_label(uint32_t accountIndex, uint32_t addressIndex, char *label);
DLL_EXPORT void subaddress_refresh(uint32_t accountIndex);
DLL_EXPORT int32_t account_size();
DLL_EXPORT int64_t *account_get_all();
DLL_EXPORT void account_add_row(char *label);
DLL_EXPORT void account_set_label_row(uint32_t account_index, char *label);
DLL_EXPORT void account_refresh();
DLL_EXPORT int64_t *transactions_get_all();
DLL_EXPORT void transactions_refresh();
DLL_EXPORT int64_t transactions_count();
DLL_EXPORT int LedgerExchange(
DLL_EXPORT int LedgerFind(char *buffer, size_t len);
DLL_EXPORT void on_startup();
DLL_EXPORT void rescan_blockchain();
DLL_EXPORT char * get_tx_key(char * txId);
DLL_EXPORT char *get_subaddress_label(uint32_t accountIndex, uint32_t addressIndex);
DLL_EXPORT void set_trusted_daemon(bool arg);
DLL_EXPORT bool trusted_daemon();
DLL_EXPORT bool validate_address(char *address);

#ifdef __cplusplus
}
#endif
