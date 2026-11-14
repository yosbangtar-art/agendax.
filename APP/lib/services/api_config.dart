/// Dirección del backend (FastAPI).
///
///  - Chrome / Windows / macOS / Linux: http://127.0.0.1:8001
///  - Emulador Android:                 http://10.0.2.2:8001
///  - Celular real: http://IP-DEL-PC:8001 (y uvicorn con host 0.0.0.0)
///
/// También se puede cambiar sin tocar el código:
///   flutter run --dart-define=API_URL=http://192.168.1.50:8001
const String kApiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://127.0.0.1:8001',
);
