// Application-wide configuration constants

// ──────────────────────────────────────────────────────────────
// Durations
// ──────────────────────────────────────────────────────────────

/// Default snackbar display duration
const Duration kSnackBarDuration = Duration(seconds: 1);

/// Snackbar duration for important messages (photo saved, etc.)
const Duration kSnackBarDurationLong = Duration(seconds: 2);

/// Camera switch animation duration
const Duration kCameraSwitchDuration = Duration(milliseconds: 300);

/// Delay before setting up augmented images (wait for session ready)
const Duration kAugmentedImageSetupDelay = Duration(milliseconds: 500);


// ──────────────────────────────────────────────────────────────
// Asset Paths
// ──────────────────────────────────────────────────────────────

/// Default World AR model path
const String kDefaultWorldModelPath = 'assets/models/world/eva_01_esg.glb';

/// Reticle model path for World AR placement
const String kReticlePath = 'assets/models/test_reticle.glb';


// ──────────────────────────────────────────────────────────────
// WebView
// ──────────────────────────────────────────────────────────────

/// WebView URL for the main menu
/// Use 10.0.2.2 for Android emulator to access localhost
const String kWebViewUrl = 'http://10.0.2.2:8000';


// ──────────────────────────────────────────────────────────────
// AR Settings
// ──────────────────────────────────────────────────────────────

/// Enable/disable augmented image detection feature
const bool kEnableAugmentedImages = false;

/// Reticle scale
const double kReticleScale = 0.15;

/// Default model scale for World AR
const double kDefaultModelScale = 1.0;