useya@Mac-mini-de-useya ARPoseMoible % ls -la
total 104
drwxr-xr-x@ 19 useya  staff    608 Dec 23 14:16 .
drwxr-xr-x@  8 useya  staff    256 Dec 23 14:04 ..
drwxr-xr-x@  7 useya  staff    224 Dec 23 14:16 .dart_tool
-rw-r--r--@  1 useya  staff   6950 Dec 23 14:16 .flutter-plugins-dependencies
-rw-r--r--@  1 useya  staff    703 Dec 23 14:04 .gitignore
-rw-r--r--@  1 useya  staff   1706 Dec 23 14:04 .metadata
-rw-r--r--@  1 useya  staff    555 Dec 23 14:04 README.md
-rw-r--r--@  1 useya  staff   1420 Dec 23 14:04 analysis_options.yaml
drwxr-xr-x@ 10 useya  staff    320 Dec 23 14:16 android
drwxr-xr-x@  4 useya  staff    128 Dec 23 14:04 assets
drwxr-xr-x@ 11 useya  staff    352 Dec 24 16:10 ios
drwxr-xr-x@  9 useya  staff    288 Dec 24 15:39 lib
drwxr-xr-x@  6 useya  staff    192 Dec 23 14:04 linux
drwxr-xr-x@  9 useya  staff    288 Dec 24 16:06 macos
-rw-r--r--@  1 useya  staff  16853 Dec 23 14:16 pubspec.lock
-rw-r--r--@  1 useya  staff   4189 Dec 23 14:04 pubspec.yaml
drwxr-xr-x@  3 useya  staff     96 Dec 23 14:04 test
drwxr-xr-x@  6 useya  staff    192 Dec 23 14:04 web
drwxr-xr-x@  6 useya  staff    192 Dec 23 14:04 windows
useya@Mac-mini-de-useya ARPoseMoible % cqt pubseck.yaml | grep -A 10 "dependencies"
zsh: command not found: cqt
useya@Mac-mini-de-useya ARPoseMoible % cat pubseck.yaml | grep -A 10 "dependencies"
cat: pubseck.yaml: No such file or directory
useya@Mac-mini-de-useya ARPoseMoible % cat pubspec.yaml | grep -A 10 "dependencies"
# To automatically upgrade your package dependencies to the latest versions
# consider running `flutter pub upgrade --major-versions`. Alternatively,
# dependencies can be manually updated by changing the version numbers below to
# the latest version available on pub.dev. To see which dependencies have newer
# versions available, run `flutter pub outdated`.
dependencies:
  flutter:
    sdk: flutter

  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.8
  webview_flutter: ^4.13.0
  flutter_inappwebview: ^6.1.5
  vector_math: ^2.2.0
  path_provider: ^2.1.5
--
dev_dependencies:
  flutter_test:
    sdk: flutter

  # The "flutter_lints" package below contains a set of recommended lints to
  # encourage good coding practices. The lint set provided by the package is
  # activated in the `analysis_options.yaml` file located at the root of your
  # package. See that file for information about deactivating specific lint
  # rules and activating additional ones.
  flutter_lints: ^5.0.0

--
  # For details regarding adding assets from package dependencies, see
  # https://flutter.dev/to/asset-from-package

  # To add custom fonts to your application, add a fonts section here,
  # in this "flutter" section. Each entry in this list should have a
  # "family" key with the font family name, and a "fonts" key with a
  # list giving the asset and other descriptors for the font. For
  # example:
  # fonts:
  #   - family: Schyler
  #     fonts:
--
  # For details regarding fonts from package dependencies,
  # see https://flutter.dev/to/font-from-package
useya@Mac-mini-de-useya ARPoseMoible % 
