class ApiConfig {
  // This project's backend always runs on port 2332 (not the NestJS
  // default 3000) — see .env PORT=2332 in the backend project.
  // - Android emulator talking to localhost backend: http://10.0.2.2:2332/api
  // - iOS simulator / Flutter Web (Chrome) on same machine: http://localhost:2332/api
  // - Real device: http://<your-computer-lan-ip>:2332/api
  //static const String baseUrl = 'http://localhost:2332/api';
  //static const String baseUrl = 'http://209.97.172.105:2332/api';
static const String baseUrl = 'https://api.mungkonefarm.com/api';

  // Uploaded images (store logos/covers, product photos) are served at
  // the ROOT of the backend, not under /api — this strips the /api
  // suffix so image URLs like "/uploads/stores/xyz.jpg" resolve right.
  static String get mediaBaseUrl =>
      baseUrl.endsWith('/api') ? baseUrl.substring(0, baseUrl.length - 4) : baseUrl;
}

class AppColors {
  // Primary Brand Green
  static const int primaryValue = 0xFF166534;
  // Accent Green
  static const int accentValue = 0xFF22C55E;
  // Fresh Highlight
  static const int freshValue = 0xFF4ADE80;
  // Background
  static const int backgroundValue = 0xFFF8FAF8;
  // Text
  static const int textDarkValue = 0xFF1F2937;
  static const int textMutedValue = 0xFF6B7280;
  // Extras
  static const int whiteValue = 0xFFFFFFFF;
  static const int borderValue = 0xFFE5E7EB;
  static const int errorValue = 0xFFDC2626;
  static const int warningValue = 0xFFF59E0B;
}
