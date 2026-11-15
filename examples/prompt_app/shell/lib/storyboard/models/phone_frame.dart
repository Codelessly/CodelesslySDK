/// Represents a phone frame configuration for the storyboard viewer
///
/// ## Understanding Device Pixel Ratio (DPR)
///
/// Device Pixel Ratio is the ratio between physical pixels and CSS/logical pixels:
/// - **Physical Resolution** = CSS Pixels × Device Pixel Ratio
/// - **CSS Pixels** = Physical Resolution ÷ Device Pixel Ratio
///
/// For example:
/// - iPhone 17: 2778×1284 physical pixels ÷ 3.0 DPR = 926×428 CSS pixels
/// - In portrait mode: width=428, height=926
///
/// The width and height in this class represent CSS/logical pixels,
/// which are the dimensions you use in Flutter layouts.
///
/// Updated: January 28, 2026
/// Research: See DEVICE_SPECS_RESEARCH.md for detailed specifications
class PhoneFrame {
  final String name;
  final double width;
  final double height;
  final double borderRadius;
  final String platform; // 'ios' or 'android'
  final String description;
  final double devicePixelRatio;

  const PhoneFrame({
    required this.name,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.platform,
    required this.description,
    this.devicePixelRatio = 3.0, // Default to 3x for modern devices
  });

  /// Common aspect ratio calculators
  double get aspectRatio => width / height;
}

/// Predefined phone frames based on common devices
class PhoneFrames {
  // No frame option
  static const PhoneFrame none = PhoneFrame(
    name: 'No Frame',
    width: 375,
    height: 812,
    borderRadius: 0,
    platform: 'none',
    description: 'No device frame',
    devicePixelRatio: 3.0,
  );

  // ============================================
  // iOS DEVICES (2025-2026)
  // ============================================

  /// iPhone 17 (2025)
  /// Physical: 2778×1284px, DPR: 3.0
  static const PhoneFrame iphone17 = PhoneFrame(
    name: 'iPhone 17',
    width: 428,
    height: 926,
    borderRadius: 55,
    platform: 'ios',
    description: 'iPhone 17 (6.3")',
    devicePixelRatio: 3.0,
  );

  /// iPhone 17 Pro (2025)
  /// Physical: 2622×1206px, DPR: 3.0
  static const PhoneFrame iphone17Pro = PhoneFrame(
    name: 'iPhone 17 Pro',
    width: 402,
    height: 874,
    borderRadius: 55,
    platform: 'ios',
    description: 'iPhone 17 Pro (6.3")',
    devicePixelRatio: 3.0,
  );

  /// iPhone SE (4th generation, 2025)
  /// Physical: 2532×1170px, DPR: 3.0
  static const PhoneFrame iphoneSE4 = PhoneFrame(
    name: 'iPhone SE',
    width: 390,
    height: 844,
    borderRadius: 47,
    platform: 'ios',
    description: 'iPhone SE 4th gen (6.1")',
    devicePixelRatio: 3.0,
  );

  /// iPad Pro 11" (M5, 2025)
  static const PhoneFrame ipadPro11 = PhoneFrame(
    name: 'iPad Pro 11"',
    width: 1210,
    height: 834,
    borderRadius: 18,
    platform: 'ios',
    description: 'iPad Pro 11" M5 (2025)',
    devicePixelRatio: 2.0,
  );


  // ============================================
  // ANDROID DEVICES (2025-2026)
  // ============================================

  /// Google Pixel 10 (2025)
  static const PhoneFrame pixel10 = PhoneFrame(
    name: 'Pixel 10',
    width: 411,
    height: 922,
    borderRadius: 40,
    platform: 'android',
    description: 'Google Pixel 10 (6.3")',
    devicePixelRatio: 2.625,
  );

  /// Google Pixel 10 Pro (2025)
  static const PhoneFrame pixel10Pro = PhoneFrame(
    name: 'Pixel 10 Pro',
    width: 427,
    height: 952,
    borderRadius: 40,
    platform: 'android',
    description: 'Google Pixel 10 Pro (6.3")',
    devicePixelRatio: 3.0,
  );


  // ============================================
  // ALL FRAMES LIST
  // ============================================

  static const List<PhoneFrame> all = [
    none,
    iphone17,
    iphone17Pro,
    iphoneSE4,
    ipadPro11,
    pixel10,
    pixel10Pro,
  ];

  static const List<PhoneFrame> ios = [
    iphone17,
    iphone17Pro,
    iphoneSE4,
    ipadPro11,
  ];

  static const List<PhoneFrame> android = [
    pixel10,
    pixel10Pro,
  ];
}
