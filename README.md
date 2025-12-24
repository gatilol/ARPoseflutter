useya@Mac-mini-de-useya ARPoseMoible % flutter doctor
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.38.5, on macOS 15.3.1 24D70 darwin-arm64, locale fr-JP)
[✗] Android toolchain - develop for Android devices
    ✗ Unable to locate Android SDK.
      Install Android Studio from: https://developer.android.com/studio/index.html
      On first launch it will assist you in installing the Android SDK components.
      (or visit https://flutter.dev/to/macos-android-setup for detailed instructions).
      If the Android SDK has been installed to a custom location, please use
      `flutter config --android-sdk` to update to that location.

[✗] Xcode - develop for iOS and macOS
    ✗ Xcode installation is incomplete; a full installation is necessary for iOS and macOS development.
      Download at: https://developer.apple.com/xcode/
      Or install Xcode via the App Store.
      Once installed, run:
        sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
        sudo xcodebuild -runFirstLaunch
    ✗ CocoaPods not installed.
        CocoaPods is a package manager for iOS or macOS platform code.
        Without CocoaPods, plugins will not work on iOS or macOS.
        For more info, see https://flutter.dev/to/platform-plugins
      For installation instructions, see https://guides.cocoapods.org/using/getting-started.html#installation
[✗] Chrome - develop for the web (Cannot find Chrome executable at /Applications/Google Chrome.app/Contents/MacOS/Google Chrome)
    ! Cannot find Chrome. Try setting CHROME_EXECUTABLE to a Chrome executable.
[✓] Connected device (1 available)
[✓] Network resources

! Doctor found issues in 3 categories.
useya@Mac-mini-de-useya ARPoseMoible %  
 *  History restored 

useya@Mac-mini-de-useya ARPoseMoible % 
 *  History restored 

useya@Mac-mini-de-useya ARPoseMoible % sudo xcodebuild -license accept
Password:
useya@Mac-mini-de-useya ARPoseMoible % sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
useya@Mac-mini-de-useya ARPoseMoible % flutter doctor                                                       
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.38.5, on macOS 26.2 25C56 darwin-arm64, locale fr-JP)
[✗] Android toolchain - develop for Android devices
    ✗ Unable to locate Android SDK.
      Install Android Studio from: https://developer.android.com/studio/index.html
      On first launch it will assist you in installing the Android SDK components.
      (or visit https://flutter.dev/to/macos-android-setup for detailed instructions).
      If the Android SDK has been installed to a custom location, please use
      `flutter config --android-sdk` to update to that location.

[!] Xcode - develop for iOS and macOS (Xcode 26.2)
    ✗ Unable to get list of installed Simulator runtimes.
    ✗ CocoaPods not installed.
        CocoaPods is a package manager for iOS or macOS platform code.
        Without CocoaPods, plugins will not work on iOS or macOS.
        For more info, see https://flutter.dev/to/platform-plugins
      For installation instructions, see https://guides.cocoapods.org/using/getting-started.html#installation
[✗] Chrome - develop for the web (Cannot find Chrome executable at /Applications/Google Chrome.app/Contents/MacOS/Google Chrome)
    ! Cannot find Chrome. Try setting CHROME_EXECUTABLE to a Chrome executable.
[✓] Connected device (1 available)
    ! Error: 大子修のiPhone is not available because it is unpaired. Pair with the device in the Xcode Devices Window, and respond to any pairing prompts
      on the device. (code -29)
[✓] Network resourcess

! Doctor found issues in 3 categories.
