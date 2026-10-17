part of 'main.dart';

// Colours of the Linkzora look in a night (dark) and a day (light) variant.
// Widgets read them with `context.palette`; the theme carries the palette as
// a ThemeExtension, so switching modes animates every colour with the theme.

const _darkModeKey = 'darkMode';

class LinkzoraPalette extends ThemeExtension<LinkzoraPalette> {
  const LinkzoraPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceBright,
    required this.text,
    required this.textSoft,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.slow,
    required this.offline,
    required this.info,
    required this.paused,
    required this.brand,
    required this.panel,
    required this.panelRaised,
    required this.panelBorder,
    required this.dial,
    required this.glow,
    required this.shadow,
    required this.tooltip,
    required this.spinner,
    required this.spinnerTrack,
  });

  final Brightness brightness;

  /// Screen background; also tinted with alpha for recessed wells.
  final Color bg;
  final Color surface;

  /// Floating surfaces: menus and toasts.
  final Color surfaceBright;
  final Color text;
  final Color textSoft;
  final Color muted;

  /// Stable state and the main highlight.
  final Color accent;

  /// Text and icons drawn on [accent] or the [brand] gradient.
  final Color onAccent;
  final Color slow;
  final Color offline;
  final Color info;
  final Color paused;

  /// Brand gradient stops (buttons, filled badges, tab indicator).
  final List<Color> brand;

  /// Default panel gradient.
  final List<Color> panel;

  /// Highlighted panels, sheets and the server dropdown.
  final List<Color> panelRaised;
  final Color panelBorder;

  /// Face of the status ring on Conexão (top-left to bottom-right).
  final List<Color> dial;

  /// Glow behind the brand icon.
  final Color glow;
  final Color shadow;

  /// Chart tooltip background.
  final Color tooltip;
  final Color spinner;
  final Color spinnerTrack;

  static const dark = LinkzoraPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF07121E),
    surface: Color(0xFF0E2030),
    surfaceBright: Color(0xFF152B3D),
    text: Colors.white,
    textSoft: Color(0xB3FFFFFF),
    muted: Color(0xFF8EA4B3),
    accent: Color(0xFF20E3A2),
    onAccent: Color(0xFF07121E),
    slow: Color(0xFFFFC857),
    offline: Color(0xFFFF6B78),
    info: Color(0xFF70B7FF),
    paused: Color(0xFF607888),
    brand: [Color(0xFF20E3A2), Color(0xFF28B8F0)],
    panel: [Color(0xFF10283A), Color(0xFF0B1B29)],
    panelRaised: [Color(0xFF153449), Color(0xFF0C2732)],
    panelBorder: Color(0x1F70B7FF),
    dial: [Color(0xFF10263A), Color(0xFF0B1C2A)],
    glow: Color(0xFF246DFF),
    shadow: Color(0x73000000),
    tooltip: Color(0xF0152B3D),
    spinner: Color(0xFF28DDF0),
    spinnerTrack: Color(0xFF163553),
  );

  /// State colours are darker than in [dark] to stay readable on white.
  static const light = LinkzoraPalette(
    brightness: Brightness.light,
    bg: Color(0xFFEEF3F7),
    surface: Color(0xFFFFFFFF),
    surfaceBright: Color(0xFFFFFFFF),
    text: Color(0xFF0B1B29),
    textSoft: Color(0xFF34495A),
    muted: Color(0xFF5B7183),
    accent: Color(0xFF0B9A70),
    onAccent: Colors.white,
    slow: Color(0xFFB7740F),
    offline: Color(0xFFD33445),
    info: Color(0xFF2A78D0),
    paused: Color(0xFF8A9BA8),
    brand: [Color(0xFF0FA67A), Color(0xFF1B8FD0)],
    panel: [Color(0xFFFFFFFF), Color(0xFFF5F9FC)],
    panelRaised: [Color(0xFFE3F6EF), Color(0xFFE2EFF9)],
    panelBorder: Color(0x1A0B1B29),
    dial: [Color(0xFFFAFCFE), Color(0xFFE7EEF4)],
    glow: Color(0xFF246DFF),
    shadow: Color(0x240B1B29),
    tooltip: Color(0xF5FFFFFF),
    spinner: Color(0xFF1B8FD0),
    spinnerTrack: Color(0xFFD5E2EC),
  );

  bool get isDark => brightness == Brightness.dark;

  LinearGradient get brandGradient => LinearGradient(colors: brand);

  Color stateColor(String state) => switch (state) {
        'offline' => offline,
        'slow' => slow,
        _ => accent,
      };

  /// Status and navigation bar icons that contrast with [bg].
  SystemUiOverlayStyle get overlayStyle => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: brightness,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      );

  ThemeData get theme {
    final base = isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: brightness,
        surface: surface,
      ),
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      iconTheme: IconThemeData(color: text),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: .3),
        selectionHandleColor: accent,
      ),
      extensions: [this],
    );
  }

  @override
  LinkzoraPalette copyWith() => this;

  @override
  LinkzoraPalette lerp(LinkzoraPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> g(List<Color> a, List<Color> b) =>
        [for (var i = 0; i < a.length; i++) c(a[i], b[i])];
    return LinkzoraPalette(
      brightness: t < .5 ? brightness : other.brightness,
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surfaceBright: c(surfaceBright, other.surfaceBright),
      text: c(text, other.text),
      textSoft: c(textSoft, other.textSoft),
      muted: c(muted, other.muted),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      slow: c(slow, other.slow),
      offline: c(offline, other.offline),
      info: c(info, other.info),
      paused: c(paused, other.paused),
      brand: g(brand, other.brand),
      panel: g(panel, other.panel),
      panelRaised: g(panelRaised, other.panelRaised),
      panelBorder: c(panelBorder, other.panelBorder),
      dial: g(dial, other.dial),
      glow: c(glow, other.glow),
      shadow: c(shadow, other.shadow),
      tooltip: c(tooltip, other.tooltip),
      spinner: c(spinner, other.spinner),
      spinnerTrack: c(spinnerTrack, other.spinnerTrack),
    );
  }
}

extension _PaletteContext on BuildContext {
  /// The current palette; screens built outside [Linkzora] fall back to dark.
  LinkzoraPalette get palette =>
      Theme.of(this).extension<LinkzoraPalette>() ?? LinkzoraPalette.dark;
}

/// Night mode switch, persisted in SharedPreferences under [_darkModeKey].
class _Appearance extends ValueNotifier<bool> {
  _Appearance(super.darkMode);

  bool get darkMode => value;

  Future<void> setDarkMode(bool dark) async {
    value = dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, dark);
  }
}

class _AppearanceScope extends InheritedNotifier<_Appearance> {
  const _AppearanceScope(
      {required _Appearance appearance, required super.child})
      : super(notifier: appearance);

  /// Null when a screen is pumped without [Linkzora] (as in widget tests).
  static _Appearance? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppearanceScope>()?.notifier;
}
