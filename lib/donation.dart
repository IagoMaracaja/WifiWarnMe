part of 'main.dart';

// "Pague um cafezinho": a donation card at the end of Ajustes and, once, a
// gentle nudge on Conexão after a week of use. The button opens Buy Me a
// Coffee in the external browser.

const donationUrl = 'https://buymeacoffee.com/andremaracaja';

/// When Home first opened (ms since epoch); the nudge waits [_donationNudgeAfter].
const _firstUseKey = 'firstUseAt';

/// Set once the nudge was dismissed or used; it never comes back.
const _donationNudgeDoneKey = 'donationNudgeDone';

const _donationNudgeAfter = Duration(days: 7);

/// Whether the one-time nudge should show; records the first use on the
/// first call.
Future<bool> _donationNudgeDue(SharedPreferences prefs) async {
  if (prefs.getBool(_donationNudgeDoneKey) ?? false) return false;
  final now = DateTime.now().millisecondsSinceEpoch;
  final firstUse = prefs.getInt(_firstUseKey);
  if (firstUse == null) {
    await prefs.setInt(_firstUseKey, now);
    return false;
  }
  return now - firstUse >= _donationNudgeAfter.inMilliseconds;
}

/// Opens [donationUrl] outside the app; a failure becomes an error toast.
Future<void> _openDonation(BuildContext context) async {
  final message = context.l10n.donationOpenFailed;
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse(donationUrl),
        mode: LaunchMode.externalApplication);
  } on PlatformException {
    opened = false;
  }
  if (!opened && context.mounted) _showToast(context, message, error: true);
}

/// Coffee card with the friendly message and the Buy Me a Coffee button.
/// With [onDone] it is the one-time nudge: it gets a dismiss button and
/// [onDone] runs after it is dismissed or used.
class _DonationCard extends StatelessWidget {
  const _DonationCard({this.onDone});

  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    return _Panel(
      raised: true,
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 18),
      borderColor: p.slow.withValues(alpha: .28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CoffeeBadge(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.donationTitle,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(l.donationMessage,
                        style: TextStyle(
                            color: p.textSoft, fontSize: 13, height: 1.35)),
                  ],
                ),
              ),
              if (onDone != null)
                IconButton(
                  key: const ValueKey('donation-dismiss'),
                  tooltip: l.donationDismiss,
                  visualDensity: VisualDensity.compact,
                  onPressed: onDone,
                  icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
                )
              else
                const SizedBox(width: 6),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _GradientButton(
              label: l.donationButton,
              icon: Icons.favorite_rounded,
              onPressed: () async {
                await _openDonation(context);
                onDone?.call();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A warm cup with a little steam, in the badge shape of the app.
class _CoffeeBadge extends StatelessWidget {
  const _CoffeeBadge();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 52,
      height: 56,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          const _IconBadge(icon: Icons.coffee_rounded, filled: true, size: 48),
          Positioned(
            top: 0,
            child: Row(
              children: [
                for (final offset in [2.0, -1.0, 2.0])
                  Container(
                    width: 3,
                    height: 7,
                    margin: EdgeInsets.fromLTRB(2, offset + 1, 2, 0),
                    decoration: BoxDecoration(
                      color: p.slow.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
