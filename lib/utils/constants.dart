class AppConstants {
  static const String appName = 'Clockin Admin';

  // Firebase collection names
  static const String teamsCollection = 'teams';
  static const String eventsCollection = 'events';
  static const String skeletonCollection = 'skeleton';
  static const String organizationsCollection = 'organizations';
  static const String adminUsersCollection = 'adminUsers';

  // QR scan status types
  static const List<String> scanTypes = [
    'checkin',
    'lunch',
    'dinner',
    'checkout',
  ];

  // App padding and spacing
  static const double defaultPadding = 16.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 32.0;

  // Border radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusRound = 100.0;

  // Animation durations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);

  // Card elevation
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMed = 4.0;
  static const double elevationHigh = 8.0;
}
