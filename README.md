useya@Mac-mini-de-useya ios % pod install --repo-update                                                                
Updating local specs repositories
Analyzing dependencies
Downloading dependencies
Installing Flutter (1.0.0)
Installing GLTFSceneKit (0.3.0)
Installing OrderedSet (6.0.3)
Installing ar_flutter_plugin_2 (1.0.0)
Installing flutter_inappwebview_ios (0.0.1)
Installing gal (1.0.0)
Installing geolocator_apple (1.2.0)
Installing path_provider_foundation (0.0.1)
Installing permission_handler_apple (9.3.0)
Installing webview_flutter_wkwebview (0.0.1)
Generating Pods project
[!] An error occurred while processing the post-install hook of the Podfile.

/Users/useya/flutter/bin/cache/artifacts/engine/ios/Flutter.xcframework must exist. If you're running pod install manually, make sure "flutter precache --ios" is executed first

/Users/useya/flutter/packages/flutter_tools/bin/podhelper.rb:61:in 'Object#flutter_additional_ios_build_settings'
/Users/useya/ARPoseflutter/ARPoseMoible/ios/Podfile:41:in 'block (3 levels) in Pod::Podfile.from_ruby'
/Users/useya/ARPoseflutter/ARPoseMoible/ios/Podfile:40:in 'Array#each'
/Users/useya/ARPoseflutter/ARPoseMoible/ios/Podfile:40:in 'block (2 levels) in Pod::Podfile.from_ruby'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-core-1.16.2/lib/cocoapods-core/podfile.rb:196:in 'Pod::Podfile#post_install!'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-1.16.2/lib/cocoapods/installer.rb:1013:in 'Pod::Installer#run_podfile_post_install_hook'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-1.16.2/lib/cocoapods/installer.rb:1001:in 'block in Pod::Installer#run_podfile_post_install_hooks'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-1.16.2/lib/cocoapods/user_interface.rb:149:in 'Pod::UserInterface.message'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-1.16.2/lib/cocoapods/installer.rb:1000:in 'Pod::Installer#run_podfile_post_install_hooks'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-1.16.2/lib/cocoapods/installer.rb:337:in 'block (2 levels) in Pod::Installer#create_and_save_projects'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-1.16.2/lib/cocoapods/installer/xcode/pods_project_generator/pods_project_writer.rb:61:in 'Pod::Installer::Xcode::PodsProjectWriter#write!'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-1.16.2/lib/cocoapods/installer.rb:336:in 'block in Pod::Installer#create_and_save_projects'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-1.16.2/lib/cocoapods/user_interface.rb:64:in 'Pod::UserInterface.section'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-1.16.2/lib/cocoapods/installer.rb:315:in 'Pod::Installer#create_and_save_projects'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-1.16.2/lib/cocoapods/installer.rb:307:in 'Pod::Installer#generate_pods_project'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-1.16.2/lib/cocoapods/installer.rb:183:in 'Pod::Installer#integrate'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-1.16.2/lib/cocoapods/installer.rb:170:in 'Pod::Installer#install!'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-1.16.2/lib/cocoapods/command/install.rb:52:in 'Pod::Command::Install#run'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/claide-1.1.0/lib/claide/command.rb:334:in 'CLAide::Command.run'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-1.16.2/lib/cocoapods/command.rb:52:in 'Pod::Command.run'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/gems/cocoapods-1.16.2/bin/pod:55:in '<top (required)>'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/bin/pod:25:in 'Kernel#load'
/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec/bin/pod:25:in '<main>'

[!] Automatically assigning platform `iOS` with version `13.0` on target `Runner` because no platform was specified. Please specify a platform for this target in your Podfile. See `https://guides.cocoapods.org/syntax/podfile.html#platform`.
useya@Mac-mini-de-useya ios % 
