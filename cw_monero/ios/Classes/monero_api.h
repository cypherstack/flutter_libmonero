#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>
#include "CwWalletListener.h"

// Define a macro for exporting functions on Windows.
#if defined(_WIN32) || defined(_WIN64) || defined(__declspec) || defined(BUILDING_FOR_WINDOWS)
#define DLL_EXPORT __declspec(dllexport)
#else
#define DLL_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

extern DLL_EXPORT void change_current_wallet(Monero::Wallet *wallet);
extern DLL_EXPORT Monero::Wallet *get_current_wallet();
extern DLL_EXPORT bool create_wallet(char *path, char *password, char *language, int32_t networkType, char *error);
extern DLL_EXPORT bool restore_wallet_from_seed(char *path, char *password, char *seed, int32_t networkType, uint64_t restoreHeight, char *error);
extern DLL_EXPORT bool restore_wallet_from_keys(char *path, char *password, char *language, char *address, char *viewKey, char *spendKey, int32_t networkType, uint64_t restoreHeight, char *error);
extern DLL_EXPORT bool load_wallet(char *path, char *password, int32_t nettype);
extern DLL_EXPORT char *error_string() {
extern DLL_EXPORT bool is_wallet_exist(char *path);
extern DLL_EXPORT void close_current_wallet();
extern DLL_EXPORT char *get_filename();
extern DLL_EXPORT char *secret_view_key();
extern DLL_EXPORT char *public_view_key();
extern DLL_EXPORT char *secret_spend_key();
extern DLL_EXPORT char *public_spend_key();
extern DLL_EXPORT char *get_address(uint32_t account_index, uint32_t address_index);
extern DLL_EXPORT const char *seed();
extern DLL_EXPORT uint64_t get_full_balance(uint32_t account_index);
extern DLL_EXPORT uint64_t get_unlocked_balance(uint32_t account_index);
extern DLL_EXPORT uint64_t get_current_height();
extern DLL_EXPORT uint64_t get_node_height();
extern DLL_EXPORT bool connect_to_node(char *error);
extern DLL_EXPORT bool setup_node(char *address, char *login, char *password, bool use_ssl, bool is_light_wallet, char *error);
extern DLL_EXPORT bool is_connected();
extern DLL_EXPORT void start_refresh();
extern DLL_EXPORT void set_refresh_from_block_height(uint64_t height);
extern DLL_EXPORT void set_recovering_from_seed(bool is_recovery);
extern DLL_EXPORT void store(char *path);
extern DLL_EXPORT bool set_password(char *password, Utf8Box &error) {
extern DLL_EXPORT bool transaction_create(char *address, char *payment_id, char *amount,
extern DLL_EXPORT bool transaction_create_mult_dest(char **addresses, char *payment_id, char **amounts, uint32_t size,
extern DLL_EXPORT bool transaction_commit(PendingTransactionRaw *transaction, Utf8Box &error);
extern DLL_EXPORT uint64_t get_node_height_or_update(uint64_t base_eight);
extern DLL_EXPORT uint64_t get_syncing_height();
extern DLL_EXPORT uint64_t is_needed_to_refresh();
extern DLL_EXPORT uint8_t is_new_transaction_exist();
extern DLL_EXPORT void set_listener();
extern DLL_EXPORT int64_t *subaddrress_get_all();
extern DLL_EXPORT int32_t subaddrress_size();
extern DLL_EXPORT void subaddress_add_row(uint32_t accountIndex, char *label);
extern DLL_EXPORT void subaddress_set_label(uint32_t accountIndex, uint32_t addressIndex, char *label);
extern DLL_EXPORT void subaddress_refresh(uint32_t accountIndex);
extern DLL_EXPORT int32_t account_size();
extern DLL_EXPORT int64_t *account_get_all();
extern DLL_EXPORT void account_add_row(char *label);
extern DLL_EXPORT void account_set_label_row(uint32_t account_index, char *label);
extern DLL_EXPORT void account_refresh();
extern DLL_EXPORT int64_t *transactions_get_all();
extern DLL_EXPORT void transactions_refresh();
extern DLL_EXPORT int64_t transactions_count();
extern DLL_EXPORT int LedgerExchange(
extern DLL_EXPORT int LedgerFind(char *buffer, size_t len);
extern DLL_EXPORT void on_startup();
extern DLL_EXPORT void rescan_blockchain();
extern DLL_EXPORT char * get_tx_key(char * txId);
extern DLL_EXPORT char *get_subaddress_label(uint32_t accountIndex, uint32_t addressIndex);
extern DLL_EXPORT void set_trusted_daemon(bool arg);
extern DLL_EXPORT bool trusted_daemon();
extern DLL_EXPORT bool validate_address(char *address);

#ifdef __cplusplus
}
#endif
