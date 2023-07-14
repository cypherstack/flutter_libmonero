//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import cw_monero
import cw_shared_external
import cw_wownero
import flutter_secure_storage_macos
import path_provider_foundation
import stack_wallet_backup

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  CwMoneroPlugin.register(with: registry.registrar(forPlugin: "CwMoneroPlugin"))
  CwSharedExternalPlugin.register(with: registry.registrar(forPlugin: "CwSharedExternalPlugin"))
  CwWowneroPlugin.register(with: registry.registrar(forPlugin: "CwWowneroPlugin"))
  FlutterSecureStoragePlugin.register(with: registry.registrar(forPlugin: "FlutterSecureStoragePlugin"))
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
  StackWalletBackupPlugin.register(with: registry.registrar(forPlugin: "StackWalletBackupPlugin"))
}
