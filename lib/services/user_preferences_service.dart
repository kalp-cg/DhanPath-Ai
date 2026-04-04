import 'package:shared_preferences/shared_preferences.dart';

/// Stores user profile & currency preferences locally
class UserPreferencesService {
  static final UserPreferencesService _instance =
      UserPreferencesService._internal();
  factory UserPreferencesService() => _instance;
  UserPreferencesService._internal();

  static const String _nameKey = 'user_name';
  static const String _countryKey = 'user_country';
  static const String _currencyCodeKey = 'user_currency_code';
  static const String _currencySymbolKey = 'user_currency_symbol';
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _simpleModeKey = 'simple_mode';
  static const String _cloudEmailKey = 'cloud_email';
  static const String _cloudDashboardUrlKey = 'cloud_dashboard_url';
  static const String _cloudFamilyIdKey = 'cloud_family_id';

  /// Production dashboard (override via [setCloudDashboardUrl] for self-hosted).
  static const String defaultCloudDashboardUrl = 'https://dhan-path-ai.vercel.app';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ─── Onboarding Status ───

  Future<bool> isOnboardingComplete() async {
    final prefs = await _preferences;
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool(_onboardingCompleteKey, value);
  }

  // ─── Simple Mode ───

  Future<bool> isSimpleMode() async {
    final prefs = await _preferences;
    return prefs.getBool(_simpleModeKey) ?? false;
  }

  Future<void> setSimpleMode(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool(_simpleModeKey, value);
  }

  // ─── Cloud Sync Preferences ───

  Future<String> getCloudEmail() async {
    final prefs = await _preferences;
    return prefs.getString(_cloudEmailKey) ?? '';
  }

  Future<void> setCloudEmail(String email) async {
    final prefs = await _preferences;
    await prefs.setString(_cloudEmailKey, email.trim().toLowerCase());
  }

  Future<String> getCloudDashboardUrl() async {
    final prefs = await _preferences;
    return prefs.getString(_cloudDashboardUrlKey) ?? '';
  }

  /// Saved URL, or [defaultCloudDashboardUrl] if the user never set one.
  Future<String> getEffectiveCloudDashboardUrl() async {
    final saved = await getCloudDashboardUrl();
    final t = saved.trim();
    return t.isNotEmpty ? t : defaultCloudDashboardUrl;
  }

  /// Persists the default dashboard URL once so background sync can run without manual setup.
  Future<void> ensureDefaultCloudDashboardUrl() async {
    final saved = await getCloudDashboardUrl();
    if (saved.trim().isEmpty) {
      await setCloudDashboardUrl(defaultCloudDashboardUrl);
    }
  }

  Future<void> setCloudDashboardUrl(String url) async {
    final prefs = await _preferences;
    await prefs.setString(_cloudDashboardUrlKey, url.trim());
  }

  Future<String> getCloudFamilyId() async {
    final prefs = await _preferences;
    return prefs.getString(_cloudFamilyIdKey) ?? '';
  }

  Future<void> setCloudFamilyId(String familyId) async {
    final prefs = await _preferences;
    await prefs.setString(_cloudFamilyIdKey, familyId.trim());
  }

  // ─── User Name ───

  Future<String> getUserName() async {
    final prefs = await _preferences;
    return prefs.getString(_nameKey) ?? '';
  }

  Future<void> setUserName(String name) async {
    final prefs = await _preferences;
    await prefs.setString(_nameKey, name);
  }

  // ─── Country ───

  Future<String> getCountry() async {
    final prefs = await _preferences;
    return prefs.getString(_countryKey) ?? '';
  }

  Future<void> setCountry(String country) async {
    final prefs = await _preferences;
    await prefs.setString(_countryKey, country);
  }

  // ─── Currency ───

  Future<String> getCurrencyCode() async {
    final prefs = await _preferences;
    return prefs.getString(_currencyCodeKey) ?? 'INR';
  }

  Future<void> setCurrencyCode(String code) async {
    final prefs = await _preferences;
    await prefs.setString(_currencyCodeKey, code);
  }

  Future<String> getCurrencySymbol() async {
    final prefs = await _preferences;
    return prefs.getString(_currencySymbolKey) ?? '₹';
  }

  Future<void> setCurrencySymbol(String symbol) async {
    final prefs = await _preferences;
    await prefs.setString(_currencySymbolKey, symbol);
  }

  // ─── Save All at Once (onboarding) ───

  Future<void> saveOnboarding({
    required String name,
    required String country,
    required String currencyCode,
    required String currencySymbol,
  }) async {
    final prefs = await _preferences;
    await prefs.setString(_nameKey, name);
    await prefs.setString(_countryKey, country);
    await prefs.setString(_currencyCodeKey, currencyCode);
    await prefs.setString(_currencySymbolKey, currencySymbol);
    await prefs.setBool(_onboardingCompleteKey, true);
    // Update the static cache
    CurrencyHelper._cachedSymbol = currencySymbol;
  }
}

/// Static helper for quick currency symbol access throughout the app
/// Avoids async calls in UI widgets
class CurrencyHelper {
  static String _cachedSymbol = '₹';
  static String _cachedCode = 'INR';
  static String _cachedName = '';

  /// Must be called once at app startup (before any UI renders)
  static Future<void> initialize() async {
    final prefs = UserPreferencesService();
    _cachedSymbol = await prefs.getCurrencySymbol();
    _cachedCode = await prefs.getCurrencyCode();
    _cachedName = await prefs.getUserName();
  }

  /// Get the user's currency symbol (e.g. ₹, $, €, £)
  static String get symbol => _cachedSymbol;

  /// Get the user's currency code (e.g. INR, USD, EUR, GBP)
  static String get code => _cachedCode;

  /// Get user's display name
  static String get userName => _cachedName;

  /// Format amount with currency symbol
  static String format(double amount, {bool compact = false}) {
    if (compact) {
      if (amount.abs() >= 10000000) {
        return '$_cachedSymbol${(amount / 10000000).toStringAsFixed(1)}Cr';
      }
      if (amount.abs() >= 100000) {
        return '$_cachedSymbol${(amount / 100000).toStringAsFixed(1)}L';
      }
      if (amount.abs() >= 1000) {
        return '$_cachedSymbol${(amount / 1000).toStringAsFixed(1)}K';
      }
    }
    if (amount == amount.roundToDouble() && amount.abs() < 100000) {
      return '$_cachedSymbol${amount.toStringAsFixed(0)}';
    }
    return '$_cachedSymbol${amount.toStringAsFixed(2)}';
  }

  /// Just the symbol prefix for text fields
  static String get prefix => _cachedSymbol;
}

/// Comprehensive country/currency data
class CountryCurrency {
  final String country;
  final String code; // ISO 4217
  final String symbol;
  final String flag; // Emoji flag

  const CountryCurrency({
    required this.country,
    required this.code,
    required this.symbol,
    required this.flag,
  });

  /// All supported countries sorted alphabetically
  static const List<CountryCurrency> all = [
    CountryCurrency(
      country: 'Afghanistan',
      code: 'AFN',
      symbol: '؋',
      flag: '🇦🇫',
    ),
    CountryCurrency(country: 'Albania', code: 'ALL', symbol: 'L', flag: '🇦🇱'),
    CountryCurrency(
      country: 'Algeria',
      code: 'DZD',
      symbol: 'د.ج',
      flag: '🇩🇿',
    ),
    CountryCurrency(
      country: 'Argentina',
      code: 'ARS',
      symbol: '\$',
      flag: '🇦🇷',
    ),
    CountryCurrency(country: 'Armenia', code: 'AMD', symbol: '֏', flag: '🇦🇲'),
    CountryCurrency(
      country: 'Australia',
      code: 'AUD',
      symbol: 'A\$',
      flag: '🇦🇺',
    ),
    CountryCurrency(country: 'Austria', code: 'EUR', symbol: '€', flag: '🇦🇹'),
    CountryCurrency(
      country: 'Azerbaijan',
      code: 'AZN',
      symbol: '₼',
      flag: '🇦🇿',
    ),
    CountryCurrency(
      country: 'Bahrain',
      code: 'BHD',
      symbol: '.د.ب',
      flag: '🇧🇭',
    ),
    CountryCurrency(
      country: 'Bangladesh',
      code: 'BDT',
      symbol: '৳',
      flag: '🇧🇩',
    ),
    CountryCurrency(
      country: 'Belarus',
      code: 'BYN',
      symbol: 'Br',
      flag: '🇧🇾',
    ),
    CountryCurrency(country: 'Belgium', code: 'EUR', symbol: '€', flag: '🇧🇪'),
    CountryCurrency(
      country: 'Bhutan',
      code: 'BTN',
      symbol: 'Nu.',
      flag: '🇧🇹',
    ),
    CountryCurrency(
      country: 'Bolivia',
      code: 'BOB',
      symbol: 'Bs.',
      flag: '🇧🇴',
    ),
    CountryCurrency(country: 'Bosnia', code: 'BAM', symbol: 'KM', flag: '🇧🇦'),
    CountryCurrency(
      country: 'Brazil',
      code: 'BRL',
      symbol: 'R\$',
      flag: '🇧🇷',
    ),
    CountryCurrency(
      country: 'Brunei',
      code: 'BND',
      symbol: 'B\$',
      flag: '🇧🇳',
    ),
    CountryCurrency(
      country: 'Bulgaria',
      code: 'BGN',
      symbol: 'лв',
      flag: '🇧🇬',
    ),
    CountryCurrency(
      country: 'Cambodia',
      code: 'KHR',
      symbol: '៛',
      flag: '🇰🇭',
    ),
    CountryCurrency(
      country: 'Canada',
      code: 'CAD',
      symbol: 'C\$',
      flag: '🇨🇦',
    ),
    CountryCurrency(country: 'Chile', code: 'CLP', symbol: '\$', flag: '🇨🇱'),
    CountryCurrency(country: 'China', code: 'CNY', symbol: '¥', flag: '🇨🇳'),
    CountryCurrency(
      country: 'Colombia',
      code: 'COP',
      symbol: '\$',
      flag: '🇨🇴',
    ),
    CountryCurrency(
      country: 'Costa Rica',
      code: 'CRC',
      symbol: '₡',
      flag: '🇨🇷',
    ),
    CountryCurrency(country: 'Croatia', code: 'EUR', symbol: '€', flag: '🇭🇷'),
    CountryCurrency(
      country: 'Czech Republic',
      code: 'CZK',
      symbol: 'Kč',
      flag: '🇨🇿',
    ),
    CountryCurrency(
      country: 'Denmark',
      code: 'DKK',
      symbol: 'kr',
      flag: '🇩🇰',
    ),
    CountryCurrency(
      country: 'Dominican Republic',
      code: 'DOP',
      symbol: 'RD\$',
      flag: '🇩🇴',
    ),
    CountryCurrency(
      country: 'Ecuador',
      code: 'USD',
      symbol: '\$',
      flag: '🇪🇨',
    ),
    CountryCurrency(country: 'Egypt', code: 'EGP', symbol: 'E£', flag: '🇪🇬'),
    CountryCurrency(country: 'Estonia', code: 'EUR', symbol: '€', flag: '🇪🇪'),
    CountryCurrency(
      country: 'Ethiopia',
      code: 'ETB',
      symbol: 'Br',
      flag: '🇪🇹',
    ),
    CountryCurrency(country: 'Finland', code: 'EUR', symbol: '€', flag: '🇫🇮'),
    CountryCurrency(country: 'France', code: 'EUR', symbol: '€', flag: '🇫🇷'),
    CountryCurrency(country: 'Georgia', code: 'GEL', symbol: '₾', flag: '🇬🇪'),
    CountryCurrency(country: 'Germany', code: 'EUR', symbol: '€', flag: '🇩🇪'),
    CountryCurrency(country: 'Ghana', code: 'GHS', symbol: 'GH₵', flag: '🇬🇭'),
    CountryCurrency(country: 'Greece', code: 'EUR', symbol: '€', flag: '🇬🇷'),
    CountryCurrency(
      country: 'Guatemala',
      code: 'GTQ',
      symbol: 'Q',
      flag: '🇬🇹',
    ),
    CountryCurrency(
      country: 'Hong Kong',
      code: 'HKD',
      symbol: 'HK\$',
      flag: '🇭🇰',
    ),
    CountryCurrency(
      country: 'Hungary',
      code: 'HUF',
      symbol: 'Ft',
      flag: '🇭🇺',
    ),
    CountryCurrency(
      country: 'Iceland',
      code: 'ISK',
      symbol: 'kr',
      flag: '🇮🇸',
    ),
    CountryCurrency(country: 'India', code: 'INR', symbol: '₹', flag: '🇮🇳'),
    CountryCurrency(
      country: 'Indonesia',
      code: 'IDR',
      symbol: 'Rp',
      flag: '🇮🇩',
    ),
    CountryCurrency(country: 'Iran', code: 'IRR', symbol: '﷼', flag: '🇮🇷'),
    CountryCurrency(country: 'Iraq', code: 'IQD', symbol: 'ع.د', flag: '🇮🇶'),
    CountryCurrency(country: 'Ireland', code: 'EUR', symbol: '€', flag: '🇮🇪'),
    CountryCurrency(country: 'Israel', code: 'ILS', symbol: '₪', flag: '🇮🇱'),
    CountryCurrency(country: 'Italy', code: 'EUR', symbol: '€', flag: '🇮🇹'),
    CountryCurrency(
      country: 'Jamaica',
      code: 'JMD',
      symbol: 'J\$',
      flag: '🇯🇲',
    ),
    CountryCurrency(country: 'Japan', code: 'JPY', symbol: '¥', flag: '🇯🇵'),
    CountryCurrency(
      country: 'Jordan',
      code: 'JOD',
      symbol: 'د.ا',
      flag: '🇯🇴',
    ),
    CountryCurrency(
      country: 'Kazakhstan',
      code: 'KZT',
      symbol: '₸',
      flag: '🇰🇿',
    ),
    CountryCurrency(country: 'Kenya', code: 'KES', symbol: 'KSh', flag: '🇰🇪'),
    CountryCurrency(
      country: 'Kuwait',
      code: 'KWD',
      symbol: 'د.ك',
      flag: '🇰🇼',
    ),
    CountryCurrency(country: 'Laos', code: 'LAK', symbol: '₭', flag: '🇱🇦'),
    CountryCurrency(country: 'Latvia', code: 'EUR', symbol: '€', flag: '🇱🇻'),
    CountryCurrency(
      country: 'Lebanon',
      code: 'LBP',
      symbol: 'ل.ل',
      flag: '🇱🇧',
    ),
    CountryCurrency(
      country: 'Lithuania',
      code: 'EUR',
      symbol: '€',
      flag: '🇱🇹',
    ),
    CountryCurrency(
      country: 'Luxembourg',
      code: 'EUR',
      symbol: '€',
      flag: '🇱🇺',
    ),
    CountryCurrency(
      country: 'Malaysia',
      code: 'MYR',
      symbol: 'RM',
      flag: '🇲🇾',
    ),
    CountryCurrency(
      country: 'Maldives',
      code: 'MVR',
      symbol: 'Rf',
      flag: '🇲🇻',
    ),
    CountryCurrency(country: 'Malta', code: 'EUR', symbol: '€', flag: '🇲🇹'),
    CountryCurrency(country: 'Mexico', code: 'MXN', symbol: '\$', flag: '🇲🇽'),
    CountryCurrency(country: 'Moldova', code: 'MDL', symbol: 'L', flag: '🇲🇩'),
    CountryCurrency(
      country: 'Mongolia',
      code: 'MNT',
      symbol: '₮',
      flag: '🇲🇳',
    ),
    CountryCurrency(
      country: 'Morocco',
      code: 'MAD',
      symbol: 'د.م.',
      flag: '🇲🇦',
    ),
    CountryCurrency(country: 'Myanmar', code: 'MMK', symbol: 'K', flag: '🇲🇲'),
    CountryCurrency(country: 'Nepal', code: 'NPR', symbol: 'रू', flag: '🇳🇵'),
    CountryCurrency(
      country: 'Netherlands',
      code: 'EUR',
      symbol: '€',
      flag: '🇳🇱',
    ),
    CountryCurrency(
      country: 'New Zealand',
      code: 'NZD',
      symbol: 'NZ\$',
      flag: '🇳🇿',
    ),
    CountryCurrency(country: 'Nigeria', code: 'NGN', symbol: '₦', flag: '🇳🇬'),
    CountryCurrency(
      country: 'North Macedonia',
      code: 'MKD',
      symbol: 'ден',
      flag: '🇲🇰',
    ),
    CountryCurrency(country: 'Norway', code: 'NOK', symbol: 'kr', flag: '🇳🇴'),
    CountryCurrency(country: 'Oman', code: 'OMR', symbol: 'ر.ع.', flag: '🇴🇲'),
    CountryCurrency(
      country: 'Pakistan',
      code: 'PKR',
      symbol: '₨',
      flag: '🇵🇰',
    ),
    CountryCurrency(
      country: 'Panama',
      code: 'PAB',
      symbol: 'B/.',
      flag: '🇵🇦',
    ),
    CountryCurrency(
      country: 'Paraguay',
      code: 'PYG',
      symbol: '₲',
      flag: '🇵🇾',
    ),
    CountryCurrency(country: 'Peru', code: 'PEN', symbol: 'S/.', flag: '🇵🇪'),
    CountryCurrency(
      country: 'Philippines',
      code: 'PHP',
      symbol: '₱',
      flag: '🇵🇭',
    ),
    CountryCurrency(country: 'Poland', code: 'PLN', symbol: 'zł', flag: '🇵🇱'),
    CountryCurrency(
      country: 'Portugal',
      code: 'EUR',
      symbol: '€',
      flag: '🇵🇹',
    ),
    CountryCurrency(country: 'Qatar', code: 'QAR', symbol: 'ر.ق', flag: '🇶🇦'),
    CountryCurrency(
      country: 'Romania',
      code: 'RON',
      symbol: 'lei',
      flag: '🇷🇴',
    ),
    CountryCurrency(country: 'Russia', code: 'RUB', symbol: '₽', flag: '🇷🇺'),
    CountryCurrency(
      country: 'Rwanda',
      code: 'RWF',
      symbol: 'FRw',
      flag: '🇷🇼',
    ),
    CountryCurrency(
      country: 'Saudi Arabia',
      code: 'SAR',
      symbol: 'ر.س',
      flag: '🇸🇦',
    ),
    CountryCurrency(
      country: 'Serbia',
      code: 'RSD',
      symbol: 'дин.',
      flag: '🇷🇸',
    ),
    CountryCurrency(
      country: 'Singapore',
      code: 'SGD',
      symbol: 'S\$',
      flag: '🇸🇬',
    ),
    CountryCurrency(
      country: 'Slovakia',
      code: 'EUR',
      symbol: '€',
      flag: '🇸🇰',
    ),
    CountryCurrency(
      country: 'Slovenia',
      code: 'EUR',
      symbol: '€',
      flag: '🇸🇮',
    ),
    CountryCurrency(
      country: 'South Africa',
      code: 'ZAR',
      symbol: 'R',
      flag: '🇿🇦',
    ),
    CountryCurrency(
      country: 'South Korea',
      code: 'KRW',
      symbol: '₩',
      flag: '🇰🇷',
    ),
    CountryCurrency(country: 'Spain', code: 'EUR', symbol: '€', flag: '🇪🇸'),
    CountryCurrency(
      country: 'Sri Lanka',
      code: 'LKR',
      symbol: 'Rs',
      flag: '🇱🇰',
    ),
    CountryCurrency(country: 'Sweden', code: 'SEK', symbol: 'kr', flag: '🇸🇪'),
    CountryCurrency(
      country: 'Switzerland',
      code: 'CHF',
      symbol: 'CHF',
      flag: '🇨🇭',
    ),
    CountryCurrency(
      country: 'Taiwan',
      code: 'TWD',
      symbol: 'NT\$',
      flag: '🇹🇼',
    ),
    CountryCurrency(
      country: 'Tanzania',
      code: 'TZS',
      symbol: 'TSh',
      flag: '🇹🇿',
    ),
    CountryCurrency(
      country: 'Thailand',
      code: 'THB',
      symbol: '฿',
      flag: '🇹🇭',
    ),
    CountryCurrency(
      country: 'Tunisia',
      code: 'TND',
      symbol: 'د.ت',
      flag: '🇹🇳',
    ),
    CountryCurrency(country: 'Turkey', code: 'TRY', symbol: '₺', flag: '🇹🇷'),
    CountryCurrency(
      country: 'Uganda',
      code: 'UGX',
      symbol: 'USh',
      flag: '🇺🇬',
    ),
    CountryCurrency(country: 'Ukraine', code: 'UAH', symbol: '₴', flag: '🇺🇦'),
    CountryCurrency(
      country: 'United Arab Emirates',
      code: 'AED',
      symbol: 'د.إ',
      flag: '🇦🇪',
    ),
    CountryCurrency(
      country: 'United Kingdom',
      code: 'GBP',
      symbol: '£',
      flag: '🇬🇧',
    ),
    CountryCurrency(
      country: 'United States',
      code: 'USD',
      symbol: '\$',
      flag: '🇺🇸',
    ),
    CountryCurrency(
      country: 'Uruguay',
      code: 'UYU',
      symbol: '\$U',
      flag: '🇺🇾',
    ),
    CountryCurrency(
      country: 'Uzbekistan',
      code: 'UZS',
      symbol: "so'm",
      flag: '🇺🇿',
    ),
    CountryCurrency(
      country: 'Venezuela',
      code: 'VES',
      symbol: 'Bs.S',
      flag: '🇻🇪',
    ),
    CountryCurrency(country: 'Vietnam', code: 'VND', symbol: '₫', flag: '🇻🇳'),
    CountryCurrency(country: 'Zambia', code: 'ZMW', symbol: 'ZK', flag: '🇿🇲'),
    CountryCurrency(
      country: 'Zimbabwe',
      code: 'ZWL',
      symbol: 'Z\$',
      flag: '🇿🇼',
    ),
  ];
}
