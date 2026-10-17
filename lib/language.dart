part of 'main.dart';

// App language. By default it follows the system (Portuguese, Spanish or
// English); an explicit choice is saved under [_languageKey]. Strings live in
// lib/l10n/app_*.arb (gen-l10n); widgets read them with `context.l10n`. The
// effective language is also sent to the native side (`setLanguage` and the
// `language` argument of start/configure/probe), which writes notifications,
// the home-screen widget and new history entries in it.

const _languageKey = 'language';

/// Saved choice that follows the system language.
const _systemLanguage = 'system';

/// Languages with translations, in the order the picker shows them.
const supportedLanguages = ['pt', 'es', 'en'];

/// Shown when no system language has a translation: English is the most
/// widely understood of the three.
const fallbackLanguage = 'en';

/// The language code the app uses for a saved [preference] ('system', 'pt',
/// 'es' or 'en'): an explicit choice wins; otherwise the first of the
/// [systemLocales] (in the user's order) that has a translation, then
/// [fallbackLanguage].
String resolveLanguage(String? preference, List<Locale> systemLocales) {
  if (supportedLanguages.contains(preference)) return preference!;
  for (final locale in systemLocales) {
    if (supportedLanguages.contains(locale.languageCode)) {
      return locale.languageCode;
    }
  }
  return fallbackLanguage;
}

/// The saved language choice plus the system locales it may follow.
class _Language extends ChangeNotifier {
  _Language(this._preference, this._systemLocales);

  String _preference;
  List<Locale> _systemLocales;

  /// 'system', 'pt', 'es' or 'en'.
  String get preference => _preference;

  set preference(String value) {
    if (value == _preference) return;
    _preference = value;
    notifyListeners();
  }

  set systemLocales(List<Locale> value) {
    final before = code;
    _systemLocales = value;
    if (code != before) notifyListeners();
  }

  /// Effective language code: 'pt', 'es' or 'en'.
  String get code => resolveLanguage(_preference, _systemLocales);

  /// The language the system choice resolves to right now.
  String get systemCode => resolveLanguage(_systemLanguage, _systemLocales);

  /// Applies [value] at once and saves it.
  Future<void> choose(String value) async {
    preference = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, value);
  }
}

class _LanguageScope extends InheritedNotifier<_Language> {
  const _LanguageScope({required _Language language, required super.child})
      : super(notifier: language);

  /// Null when a screen is pumped without [Linkzora] (as in widget tests).
  static _Language? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LanguageScope>()?.notifier;
}

/// Portuguese strings for screens built outside [Linkzora], like the palette
/// falling back to dark.
final _portugueseStrings = lookupAppLocalizations(const Locale('pt'));

extension _LocalizationsContext on BuildContext {
  /// Strings in the active language.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      _portugueseStrings;
}

/// Each language in its own name, with the flag shown next to it.
const _languageNames = {
  'pt': (name: 'Português', flag: 'BR'),
  'es': (name: 'Español', flag: 'ES'),
  'en': (name: 'English', flag: 'US'),
};

/// Section with "Sistema" plus one flag card per language; the choice applies
/// immediately. Used in Ajustes and on the welcome page of the onboarding.
class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.language});

  final _Language language;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final selected = language.preference;
    Widget card(String id) {
      final entry = _languageNames[id];
      final active = id == selected ||
          (entry == null && !supportedLanguages.contains(selected));
      return _ChoiceCard(
        key: ValueKey('language-$id'),
        compact: true,
        leading: _MarkTile(
          size: 34,
          selected: active,
          child: entry == null
              ? Icon(Icons.smartphone_rounded,
                  size: 18, color: active ? p.accent : p.muted)
              : _RoundFlag.country(entry.flag, size: 18),
        ),
        title: entry?.name ?? l.languageSystem,
        selected: active,
        onTap: () => language.choose(id),
      );
    }

    final ids = [_systemLanguage, ...supportedLanguages];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l.language),
        for (var row = 0; row < ids.length; row += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: card(ids[row])),
                const SizedBox(width: 8),
                Expanded(child: card(ids[row + 1])),
              ],
            ),
          ),
        Text(
          '${l.languageSystemHint} · ${_languageNames[language.systemCode]!.name}',
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
      ],
    );
  }
}
