#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint cw_wownero.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'cw_wownero'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.public_header_files = 'Classes/**/*.h, Classes/*.h'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
  s.libraries = 'iconv'

  s.subspec 'OpenSSL' do |openssl|
    openssl.preserve_paths = '../../../../../cw_shared_external/macos/External/macos/include/**/*.h'
    openssl.vendored_libraries = '../../../../../cw_shared_external/macos/External/macos/lib/libcrypto.a', '../../../../../cw_shared_external/macos/External/macos/lib/libssl.a'
    openssl.libraries = 'ssl', 'crypto'
    openssl.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/#{s.name}/External/macos/include/**" }
  end

  s.subspec 'Sodium' do |sodium|
    sodium.preserve_paths = '../../../../../cw_shared_external/macos/External/macos/include/**/*.h'
    sodium.vendored_libraries = '../../../../../cw_shared_external/macos/External/macos/lib/libsodium.a'
    sodium.libraries = 'sodium'
    sodium.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/#{s.name}/External/macos/include/**" }
  end

  s.subspec 'Unbound' do |unbound|
    unbound.preserve_paths = '../../../../../cw_shared_external/macos/External/macos/include/**/*.h'
    unbound.vendored_libraries = '../../../../../cw_shared_external/macos/External/macos/lib/libunbound.a'
    unbound.libraries = 'unbound'
    unbound.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/#{s.name}/External/macos/include/**" }
  end

  s.subspec 'Boost' do |boost|
    boost.preserve_paths = '../../../../../cw_shared_external/macos/External/macos/include/**/*.h',
    boost.vendored_libraries =  '../../../../../cw_shared_external/macos/External/macos/lib/libboost.a',
    boost.libraries = 'boost'
    boost.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/#{s.name}/External/macos/include/**" }
  end

  s.subspec 'Wownero' do |wownero|
    wownero.preserve_paths = 'External/macos/include/**/*.h'
    wownero.vendored_libraries = 'External/macos/lib/libwownero.a'
    wownero.libraries = 'wownero'
    wownero.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/#{s.name}/External/macos/include" }
  end
end
