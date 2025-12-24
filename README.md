useya@Mac-mini-de-useya ARPoseflutter % cat ar_flutter_plugin_2/ios/ar_flutter_plugin_2.podspec
#
# ar_flutter_plugin_2.podspec
# 
# Configuration CocoaPods pour le plugin AR Flutter
# Supporte ARKit avec Face AR, World AR, et Augmented Images
#
# Prérequis:
# - iOS 13.0 minimum (pour ARKit 3+ features)
# - Xcode 14.0+
# - Swift 5.0+
#

Pod::Spec.new do |s|
  s.name             = 'ar_flutter_plugin_2'
  s.version          = '1.0.0'
  s.summary          = 'Flutter AR Plugin with Face AR, World AR, and Augmented Images support'
  s.description      = <<-DESC
A comprehensive Flutter plugin for Augmented Reality on iOS.
Features:
- Face AR with face mesh rendering and makeup textures
- World AR with plane detection and object placement
- Augmented Images detection with 3D model overlay
- GLB/GLTF 3D model loading
- Screenshot capture
                       DESC
  s.homepage         = 'https://github.com/your-repo/ar_flutter_plugin_2'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Your Name' => 'your.email@example.com' }
  s.source           = { :path => '.' }
  
  # Source files
  s.source_files = 'Classes/**/*'
  
  # Platform requirements
  s.platform = :ios, '13.0'
  s.ios.deployment_target = '13.0'
  
  # Swift version
  s.swift_version = '5.0'
  
  # Flutter dependency
  s.dependency 'Flutter'
  
  # GLTFKit2 for loading GLB/GLTF 3D models
  # This is a well-maintained library that converts GLTF to SceneKit
  s.dependency 'GLTFKit2', '~> 0.5'
  
  # iOS Frameworks
  s.frameworks = [
    'ARKit',           # Core AR functionality
    'SceneKit',        # 3D rendering engine
    'AVFoundation',    # Camera access
    'CoreImage',       # Image processing
    'CoreGraphics',    # Graphics utilities
    'Metal',           # GPU acceleration (used by ARKit internally)
    'MetalKit'         # Metal utilities
  ]
  
  # Build settings
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    # Enable ARKit (disable TrueDepth if not using Face AR in production)
    # To disable TrueDepth API (required if not using Face AR):
    # 'OTHER_SWIFT_FLAGS' => '$(inherited) -DDISABLE_TRUEDEPTH_API'
  }
  
  # Ensure module is available
  s.static_framework = true
  
  # Resource bundles (for any assets like shaders, default textures, etc.)
  # s.resource_bundles = {
  #   'ar_flutter_plugin_2' => ['Assets/**/*']
  # }
  
  # Privacy - Camera usage is required for AR
  # Note: The app using this plugin must add NSCameraUsageDescription to Info.plist
  
end
