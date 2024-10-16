//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_libmonero/flutter_libmonero_plugin.h>
#include <stack_wallet_backup/stack_wallet_backup_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) flutter_libmonero_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterLibmoneroPlugin");
  flutter_libmonero_plugin_register_with_registrar(flutter_libmonero_registrar);
  g_autoptr(FlPluginRegistrar) stack_wallet_backup_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "StackWalletBackupPlugin");
  stack_wallet_backup_plugin_register_with_registrar(stack_wallet_backup_registrar);
}
