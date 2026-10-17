part of 'main.dart';

// Shared building blocks of the Linkzora look: gradient panels with a thin
// border, gradient icon badges, custom bottom sheets and the app chrome (top
// bar buttons and the tab bar). Colours always come from `context.palette`.

/// Gradient card used for every section of the app; [raised] highlights it.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
    this.raised = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: raised ? p.panelRaised : p.panel,
        ),
        border: Border.all(color: borderColor ?? p.panelBorder),
      ),
      child: child,
    );
  }
}

/// Rounded square holding an icon; [filled] uses the brand gradient.
class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    this.color,
    this.size = 44,
    this.filled = false,
  });

  final IconData icon;

  /// Defaults to the accent colour.
  final Color? color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = color ?? p.accent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .32),
        gradient: filled ? p.brandGradient : null,
        color: filled ? null : tint.withValues(alpha: .13),
        boxShadow: filled
            ? [BoxShadow(color: p.accent.withValues(alpha: .3), blurRadius: 18)]
            : null,
      ),
      child: Icon(icon, color: filled ? p.onAccent : tint, size: size * .52),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(text.toUpperCase(),
                  style: TextStyle(
                      color: context.palette.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// Selectable card with icon, title, description and a round check.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.compact = false,
  });

  final IconData? icon;

  /// Replaces the [icon] badge, e.g. with a [_TargetMark].
  final Widget? leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(compact ? 11 : 13),
          decoration: BoxDecoration(
            color: selected
                ? p.accent.withValues(alpha: .1)
                : p.bg.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? p.accent.withValues(alpha: .6)
                  : p.muted.withValues(alpha: .1),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              leading ??
                  _IconBadge(
                      icon: icon ?? Icons.circle_outlined,
                      color: selected ? p.accent : p.muted,
                      size: compact ? 34 : 40),
              SizedBox(width: compact ? 10 : 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: selected ? p.text : p.textSoft,
                            fontSize: compact ? 13 : 15,
                            fontWeight: FontWeight.w800)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: p.muted, fontSize: compact ? 11 : 12)),
                    ],
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                _RoundCheck(selected: selected),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundCheck extends StatelessWidget {
  const _RoundCheck({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? p.accent : Colors.transparent,
        border: Border.all(
            color: selected ? p.accent : p.muted.withValues(alpha: .45),
            width: 2),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 14, color: p.onAccent)
          : null,
    );
  }
}

/// Recessed pill track that holds selectable [_PillOption]s.
class _PillTrack extends StatelessWidget {
  const _PillTrack({required this.child, this.radius = 16, this.padding = 4});

  final Widget child;
  final double radius;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: p.bg.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: p.muted.withValues(alpha: .12)),
      ),
      child: child,
    );
  }
}

/// Option of a pill selector: filled with the accent when [selected].
class _PillOption extends StatelessWidget {
  const _PillOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.radius = 12,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(vertical: 10),
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final double radius;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.onAccent : p.muted;
    final text = Text(label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: color, fontSize: fontSize, fontWeight: FontWeight.w900));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: padding,
        decoration: BoxDecoration(
          color: selected ? p.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: icon == null
            ? text
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: fontSize + 3, color: color),
                  const SizedBox(width: 5),
                  Flexible(child: text),
                ],
              ),
      ),
    );
  }
}

/// Pill segmented control in the style of the chart range selector.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.value,
    required this.label,
    required this.onChanged,
    this.icon,
  });

  final List<T> values;
  final T value;
  final String Function(T) label;

  /// Optional glyph shown before each label.
  final IconData? Function(T)? icon;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => _PillTrack(
        child: Row(
          children: [
            for (final option in values)
              Expanded(
                child: _PillOption(
                  label: label(option),
                  icon: icon?.call(option),
                  selected: option == value,
                  onTap: () => onChanged(option),
                ),
              ),
          ],
        ),
      );
}

class _GradientButton extends StatelessWidget {
  const _GradientButton(
      {required this.label, required this.onPressed, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Opacity(
      opacity: onPressed == null ? .5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: p.brandGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: p.accent.withValues(alpha: .28),
                blurRadius: 20,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: SizedBox(
              height: 54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: p.onAccent, size: 20),
                    const SizedBox(width: 8),
                  ],
                  // Longer translations shrink instead of overflowing.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label,
                          maxLines: 1,
                          style: TextStyle(
                              color: p.onAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.muted.withValues(alpha: .22)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: p.textSoft,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

/// Panel row with an icon, a title, a caption and an on/off switch.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _Panel(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          _IconBadge(icon: icon, color: value ? p.accent : p.muted, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.muted, fontSize: 12)),
              ],
            ),
          ),
          _BrandSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _BrandSwitch extends StatelessWidget {
  const _BrandSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Switch(
      value: value,
      activeThumbColor: p.onAccent,
      activeTrackColor: p.accent,
      inactiveThumbColor: p.muted,
      inactiveTrackColor: p.bg.withValues(alpha: .6),
      trackOutlineColor: WidgetStatePropertyAll(
          value ? Colors.transparent : p.muted.withValues(alpha: .35)),
      onChanged: onChanged,
    );
  }
}

/// Bottom sheet frame: floating gradient card, handle and a branded header.
class _GlassSheet extends StatelessWidget {
  const _GlassSheet({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [p.panelRaised.first, p.panel.last],
            ),
            border: Border.all(color: p.accent.withValues(alpha: .18)),
            boxShadow: [BoxShadow(color: p.shadow, blurRadius: 40)],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.muted.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _IconBadge(icon: icon, filled: true, size: 46),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: TextStyle(color: p.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> _showGlassSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      // Keeps tall sheets (Ajustes) below the status bar.
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: context.palette.bg.withValues(alpha: .6),
      builder: builder,
    );

void _showToast(BuildContext context, String message, {bool error = false}) {
  final p = context.palette;
  final color = error ? p.offline : p.accent;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.surfaceBright,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: .35)),
      ),
      content: Row(
        children: [
          Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style:
                      TextStyle(color: p.text, fontWeight: FontWeight.w600))),
        ],
      ),
    ));
}

/// The app icon with its soft brand glow.
class _BrandIcon extends StatelessWidget {
  const _BrandIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .3),
          boxShadow: [
            BoxShadow(
                color: context.palette.glow.withValues(alpha: .3),
                blurRadius: size * .38),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: const Image(
          image: AssetImage('assets/brand/linkzora_icon.png'),
          fit: BoxFit.cover,
        ),
      );
}

/// Frosted panel behind the top bar controls and the tab bar.
class _GlassBox extends StatelessWidget {
  const _GlassBox({
    required this.child,
    required this.radius,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.blur = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Blur what is behind. Only worth it over moving content (the tab bar):
  /// the top bar sits on the plain background, where a backdrop blur shows
  /// nothing and, on some Android GPUs (Galaxy Z Fold), drew static instead.
  final bool blur;

  /// Optional state colour that tints the border and the fill.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
              color: p.shadow.withValues(alpha: p.shadow.a * .5),
              blurRadius: 18,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: _MaybeBlur(
          enabled: blur,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: shape,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                      (tint ?? p.info).withValues(alpha: .08), p.panel.first),
                  p.panel.last,
                ].map((color) => color.withValues(alpha: .88)).toList(),
              ),
              border: Border.all(
                  color: tint?.withValues(alpha: .3) ?? p.panelBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// [BackdropFilter] blur when [enabled], the bare child otherwise.
class _MaybeBlur extends StatelessWidget {
  const _MaybeBlur({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => enabled
      ? BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: child)
      : child;
}

/// Square glass button of the top bar.
class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: _GlassBox(
            radius: 14,
            blur: false,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) => RotationTransition(
                      turns:
                          Tween<double>(begin: -.25, end: 0).animate(animation),
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Icon(icon,
                        key: ValueKey(icon),
                        size: 20,
                        color: context.palette.text),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Live status pill of the top bar: a state dot that pings on every new
/// reading ([pulseKey]) and a short label.
class _LiveStatus extends StatelessWidget {
  const _LiveStatus({
    required this.color,
    required this.label,
    required this.pulseKey,
    required this.live,
  });

  final Color color;
  final String label;
  final Object pulseKey;
  final bool live;

  @override
  Widget build(BuildContext context) => _GlassBox(
        radius: 14,
        tint: color,
        blur: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(pulseKey),
                tween: Tween(begin: live ? 0 : 1, end: 1),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: 1 + t * 1.6,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: (1 - t) * .45),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        boxShadow: live
                            ? [
                                BoxShadow(
                                    color: color.withValues(alpha: .6),
                                    blurRadius: 6)
                              ]
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 7),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              // Swapped without a fade (no offscreen layer in the top bar).
              child: Text(label,
                  key: ValueKey(label),
                  maxLines: 1,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
}

typedef _TabItem = ({String label, IconData icon, IconData selectedIcon});

/// Floating glass tab bar: an accent capsule slides to the selected tab and
/// a short brand-gradient bar glows above its icon.
class _TabBar extends StatelessWidget {
  const _TabBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<_TabItem> items;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.paddingOf(context).bottom + 10),
      child: _GlassBox(
        radius: 24,
        padding: const EdgeInsets.all(5),
        child: SizedBox(
          height: 56,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth / items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    left: width * selected,
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(19),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            p.accent.withValues(alpha: .2),
                            p.accent.withValues(alpha: .06),
                          ],
                        ),
                        border:
                            Border.all(color: p.accent.withValues(alpha: .3)),
                      ),
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 22,
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: p.brandGradient,
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(3)),
                          boxShadow: [
                            BoxShadow(
                                color: p.accent.withValues(alpha: .7),
                                blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var index = 0; index < items.length; index++)
                        Expanded(
                          child: _TabButton(
                            item: items[index],
                            selected: index == selected,
                            onTap: () => onSelected(index),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton(
      {required this.item, required this.selected, required this.onTap});

  final _TabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.accent : p.muted;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: const Duration(milliseconds: 220),
                builder: (context, value, _) => Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: value,
                    size: 22),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: DefaultTextStyle.of(context).style.merge(TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: selected ? .2 : 0)),
              child: Text(item.label,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// Padding of a page shown under the floating [_TabBar].
///
/// [context] must sit inside the `Scaffold` body: with `extendBody` the
/// Scaffold folds the bar height (which already includes the bottom safe-area
/// inset) into the body's `MediaQuery` padding, so the last item can always
/// scroll fully above the bar.
EdgeInsets _tabPagePadding(BuildContext context,
        {required double horizontal, required double top}) =>
    EdgeInsets.fromLTRB(
        horizontal, top, horizontal, MediaQuery.paddingOf(context).bottom + 16);

// Visual identity of the measurement targets: the brand glyph of each anycast
// server (Simple Icons, in the brand colour) and a round flag for the regional
// endpoints. Targets are matched by the name the native side records.

const _targetBrandGlyphs = <String, IconData>{
  'Cloudflare': SimpleIcons.cloudflare,
  'Google': SimpleIcons.google,
  'Quad9': SimpleIcons.quad9,
};

const _targetBrandColors = <String, Color>{
  'Cloudflare': SimpleIconColors.cloudflare,
  'Google': SimpleIconColors.google,
  'Quad9': SimpleIconColors.quad9,
};

/// Monochrome glyph of [target] for pills; null for the regional targets.
IconData? _targetGlyph(String target) => _targetBrandGlyphs[target];

/// Round flag (São Paulo, Estados Unidos, Europa) or brand glyph of a target,
/// in any language it was recorded in; unknown targets fall back to a globe
/// in [fallbackColor].
class _TargetGlyph extends StatelessWidget {
  const _TargetGlyph(this.target, {this.size = 18, this.fallbackColor});

  final String target;
  final double size;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final glyph = _targetBrandGlyphs[target];
    if (glyph != null) {
      return Icon(glyph, size: size, color: _targetBrandColors[target]);
    }
    final flag = switch (canonicalTarget(target)) {
      'São Paulo' => _RoundFlag.country('BR', size: size),
      'Estados Unidos' => _RoundFlag.country('US', size: size),
      // The EU flag is looked up by its currency.
      'Europa' => _RoundFlag.currency('EUR', size: size),
      _ => null,
    };
    return flag ??
        Icon(Icons.public_rounded, size: size, color: fallbackColor ?? p.muted);
  }
}

/// Round flag of a country (or currency, for the EU) with a hairline ring that
/// keeps light flag edges visible on light surfaces.
class _RoundFlag extends StatelessWidget {
  const _RoundFlag.country(this.code, {required this.size}) : currency = false;
  const _RoundFlag.currency(this.code, {required this.size}) : currency = true;

  final String code;
  final bool currency;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ImageTheme(width: size, height: size, shape: const Circle());
    return Container(
      width: size,
      height: size,
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.palette.text.withValues(alpha: .14)),
      ),
      child: currency
          ? CountryFlag.fromCurrencyCode(code, theme: theme)
          : CountryFlag.fromCountryCode(code, theme: theme),
    );
  }
}

/// Rounded tile holding a glyph or flag, optionally tinted; [selected] adds
/// an accent ring.
class _MarkTile extends StatelessWidget {
  const _MarkTile({
    required this.child,
    this.size = 38,
    this.selected = false,
    this.tint,
  });

  final Widget child;
  final double size;
  final bool selected;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .32),
        color: tint?.withValues(alpha: p.isDark ? .16 : .11) ??
            p.bg.withValues(alpha: p.isDark ? .7 : 1),
        border: Border.all(
          color: selected ? p.accent.withValues(alpha: .7) : p.panelBorder,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: child,
    );
  }
}

/// [_MarkTile] with the identity of a target, tinted by its brand colour.
class _TargetMark extends StatelessWidget {
  const _TargetMark(this.target, {this.size = 38, this.selected = false});

  final String target;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final brand = _targetBrandColors[target];
    return _MarkTile(
      size: size,
      selected: selected,
      tint: brand,
      child: _TargetGlyph(target,
          size: brand == null ? size * .58 : size * .5,
          fallbackColor: context.palette.info),
    );
  }
}
