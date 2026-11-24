class CloudConfig {
  CloudConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured =>
      Uri.tryParse(url)?.hasScheme == true && publishableKey.isNotEmpty;
}
