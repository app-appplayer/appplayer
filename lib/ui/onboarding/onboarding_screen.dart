import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/app_settings.dart';
import '../../app/design_tokens.dart';
import '../../l10n/app_strings.dart';

/// MOD-UI-006 — 3-page onboarding flow.
///
/// Page 1: AppPlayer introduction.
/// Page 2: Usage guide — add apps, tap to connect, long-press to edit.
/// Page 3: Start button that navigates to the home screen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => OnboardingScreenState();
}

@visibleForTesting
class OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  /// Marks onboarding as completed and navigates to the home screen.
  Future<void> _finish(BuildContext ctx) async {
    try {
      await ctx.read<AppSettings>().markOnboardingCompleted();
    } catch (_) {
      // Continue — re-entry on next launch is acceptable.
    }
    if (!ctx.mounted) return;
    ctx.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _index = i),
                children: <Widget>[
                  _Page(
                    logo: 'assets/images/appplayer_logo.png',
                    title: S.get('onboarding.intro.title'),
                    body: S.get('onboarding.intro.body'),
                  ),
                  _Page(
                    icon: Icons.touch_app,
                    title: S.get('onboarding.guide.title'),
                    body: S.get('onboarding.guide.body'),
                  ),
                  _Page(
                    icon: Icons.rocket_launch,
                    title: S.get('onboarding.start.title'),
                    body: S.get('onboarding.start.body'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: AppSpacing.screenPadding,
              child: Row(
                children: <Widget>[
                  // Back on the left (none on the first page, the space stays
                  // so the dots remain centred), the dots in the middle, and
                  // next / start on the right.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _index == 0
                          ? const SizedBox.shrink()
                          : TextButton(
                              key: const Key('onboarding.previous'),
                              onPressed: () => _pages.previousPage(
                                duration: AppMotion.normal,
                                curve: AppMotion.standard,
                              ),
                              child: Text(S.get('onboarding.previous')),
                            ),
                    ),
                  ),
                  _Dots(
                      key: const Key('onboarding.dots'),
                      count: 3,
                      index: _index),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _index < 2
                          ? TextButton(
                              key: const Key('onboarding.next'),
                              onPressed: () => _pages.nextPage(
                                duration: AppMotion.normal,
                                curve: AppMotion.standard,
                              ),
                              child: Text(S.get('onboarding.next')),
                            )
                          : FilledButton(
                              key: const Key('onboarding.start'),
                              onPressed: () => _finish(context),
                              child: Text(S.get('onboarding.start')),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    this.icon,
    this.logo,
    required this.title,
    required this.body,
  });

  final IconData? icon;

  /// An image shown in place of [icon] (the app's logo on the first page).
  final String? logo;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Onboarding hero icon uses 1.5× the xl token (48 → 72).
          if (logo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(logo!, width: 112, height: 112),
            )
          else
            Icon(icon, size: AppIconSizes.xl * 1.5),
          const SizedBox(height: AppSpacing.base),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          Text(body, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// The page dots: the current page filled, the others outlined.
class _Dots extends StatelessWidget {
  const _Dots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          Container(
            key: Key('onboarding.dot.$i${i == index ? '.on' : ''}'),
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index ? color : Colors.transparent,
              border: Border.all(color: color, width: 1.5),
            ),
          ),
      ],
    );
  }
}
