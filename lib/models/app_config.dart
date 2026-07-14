class AppConfig {
  const AppConfig({
    this.uapiToken = '',
    this.gptsApiKey = '',
    this.gptsApiBaseUrl = 'https://api.gptsapi.net/v1',
    this.gptsApiModel = 'gpt-5.4-nano',
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
  );

  final String uapiToken;
  final String gptsApiKey;
  final String gptsApiBaseUrl;
  final String gptsApiModel;

  bool get hasUapiToken => uapiToken.trim().isNotEmpty;
  bool get hasGptsApiKey => gptsApiKey.trim().isNotEmpty;
}
