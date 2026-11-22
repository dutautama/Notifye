/// Info build yang disuntikkan CI: --dart-define=APP_VERSION="0.2.0 (build 12)".
class AppInfo {
  AppInfo._();
  static const version = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
}
