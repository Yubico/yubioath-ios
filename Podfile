# This is a workaround for Xcode 11+ bug when build reflects changes only after clean. This line disables incremental build.
# Link to the bug: https://github.com/CocoaPods/CocoaPods/issues/8073
install! 'cocoapods', :disable_input_output_paths => true

platform :ios, '11.0'

target 'Authenticator' do
  use_frameworks!

    # Use pod from submodule
    pod 'YubiKit', :path => './YubiKit'

end
