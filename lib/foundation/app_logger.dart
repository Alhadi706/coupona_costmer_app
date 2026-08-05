import 'dart:developer' as developer;

class AppLogger {
  static void info(String message) {
    developer.log(message, name: 'kupuna.info');
  }

  static void warning(String message) {
    developer.log(message, name: 'kupuna.warning', level: 900);
  }

  static void error(String message, Object error, StackTrace? stackTrace) {
    developer.log(
      message,
      name: 'kupuna.error',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
