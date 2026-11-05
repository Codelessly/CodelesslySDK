#
# Builds QuickJS and Codelessly's C API over it into the app, for
# codelessly_sdk's scripts. Classes/ holds forwarder C files that include
# the shared sources in ../src (podspecs don't take relative paths).
#
Pod::Spec.new do |s|
  s.name             = 'codelessly_quickjs'
  s.version          = '0.1.0'
  s.summary          = 'The QuickJS engine that runs Codelessly scripts.'
  s.description      = 'A sandboxed JavaScript engine (QuickJS) for codelessly_sdk scripts.'
  s.homepage         = 'https://codelessly.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Codelessly' => 'support@codelessly.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) _GNU_SOURCE=1 CONFIG_VERSION=\\"2025-04-26\\"',
    # QuickJS relies on wrapping signed arithmetic; its own warnings aren't ours.
    'OTHER_CFLAGS' => '$(inherited) -fwrapv -w',

  }
  s.swift_version = '5.0'
end
