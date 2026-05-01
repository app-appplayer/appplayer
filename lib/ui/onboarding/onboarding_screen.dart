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
                    icon: Icons.play_circle_outline,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  if (_index < 2)
                    TextButton(
                      key: const Key('onboarding.next'),
                      onPressed: () => _pages.nextPage(
                        duration: AppMotion.normal,
                        curve: AppMotion.standard,
                      ),
                      child: Text(S.get('onboarding.next')),
                    )
                  else
                    FilledButton(
                      key: const Key('onboarding.start'),
                      onPressed: () => _finish(context),
                      child: Text(S.get('onboarding.start')),
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
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
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
