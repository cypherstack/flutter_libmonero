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

DLL_EXPORT bool create_wallet(char *path, char *password, char *language, int32_t networkType, char *error);
DLL_EXPORT bool restore_wallet_from_14_word_seed(char *path, char *password, char *seed, int32_t networkType, char *error);
DLL_EXPORT bool restore_wallet_from_25_word_seed(char *path, char *password, char *seed, int32_t networkType, uint64_t restoreHeight, char *error);
DLL_EXPORT bool restore_wallet_from_keys(char *path, char *password, char *language, char *address, char *viewKey, char *spendKey, int32_t networkType, uint64_t restoreHeight, char *error);
DLL_EXPORT void load_wallet(char *path, char *password, int32_t nettype);
DLL_EXPORT bool is_wallet_exist(char *path);

DLL_EXPORT char *get_filename();
DLL_EXPORT const char *seed();
DLL_EXPORT char *get_address(uint32_t account_index, uint32_t address_index);
DLL_EXPORT uint64_t get_full_balance(uint32_t account_index);
DLL_EXPORT uint64_t get_unlocked_balance(uint32_t account_index);
DLL_EXPORT uint64_t get_current_height();
DLL_EXPORT uint64_t get_node_height();
DLL_EXPORT uint64_t get_seed_height(char *seed);

DLL_EXPORT bool is_connected();

DLL_EXPORT bool setup_node(char *address, char *login, char *password, bool use_ssl, bool is_light_wallet, char *error);
DLL_EXPORT bool connect_to_node(char *error);
DLL_EXPORT void start_refresh();
DLL_EXPORT void set_refresh_from_block_height(uint64_t height);
DLL_EXPORT void set_recovering_from_seed(bool is_recovery);
DLL_EXPORT void store(char *path);

DLL_EXPORT void set_trusted_daemon(bool arg);
DLL_EXPORT bool trusted_daemon();

DLL_EXPORT bool validate_address(char *address);

#ifdef __cplusplus
}
#endif