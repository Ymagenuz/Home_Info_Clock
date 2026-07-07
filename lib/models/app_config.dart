class AppConfig {
  const AppConfig({
    this.uapiToken = '',
    this.gptsApiKey = '',
    this.gptsApiBaseUrl = 'https://api.gptsapi.net/v1',
    this.gptsApiModel = 'gpt-5.4-nano',
    this.qweatherApiHost = 'devapi.qweather.com',
    this.qweatherApiKey = '',
    this.qweatherJwtProjectId = '',
    this.qweatherJwtKeyId = '',
    this.qweatherJwtPrivateKey = '',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
        uapiToken: String.fromEnvironment('UAPI_TOKEN'),
        gptsApiKey: String.fromEnvironment('GPTSAPI_API_KEY'),
        gptsApiBaseUrl: String.fromEnvironment(
          'GPTSAPI_BASE_URL',
          defaultValue: 'https://api.gptsapi.net/v1',
        ),
        gptsApiModel: String.fromEnvironment(
          'GPTSAPI_MODEL',
          defaultValue: 'gpt-5.4-nano',
        ),
        qweatherApiHost: String.fromEnvironment(
          'QWEATHER_API_HOST',
          defaultValue: 'devapi.qweather.com',
        ),
        qweatherApiKey: String.fromEnvironment('QWEATHER_API_KEY'),
        qweatherJwtProjectId: String.fromEnvironment('QWEATHER_JWT_PROJECT_ID'),
        qweatherJwtKeyId: String.fromEnvironment('QWEATHER_JWT_KEY_ID'),
        qweatherJwtPrivateKey: String.fromEnvironment('QWEATHER_JWT_PRIVATE_KEY'),
      );

  final String uapiToken;
  final String gptsApiKey;
  final String gptsApiBaseUrl;
  final String gptsApiModel;
  final String qweatherApiHost;
  final String qweatherApiKey;
  final String qweatherJwtProjectId;
  final String qweatherJwtKeyId;
  final String qweatherJwtPrivateKey;

  bool get hasUapiToken => uapiToken.trim().isNotEmpty;
  bool get hasGptsApiKey => gptsApiKey.trim().isNotEmpty;
  bool get hasQWeatherApiKey => qweatherApiKey.trim().isNotEmpty;
  bool get hasQWeatherJwtConfig =>
      qweatherJwtProjectId.trim().isNotEmpty &&
      qweatherJwtKeyId.trim().isNotEmpty &&
      qweatherJwtPrivateKey.trim().isNotEmpty;
}
