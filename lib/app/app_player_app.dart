import 'package:appplayer_core/appplayer_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../adapters/console_logger.dart';
import '../adapters/secure_credential_vault.dart';
import '../adapters/shared_prefs_server_storage.dart';
import '../l10n/app_strings.dart';
import '../models/app_config.dart';
import 'app_lifecycle_observer.dart';
import '../entry/entry_controller.dart';
import '../entry/deferred_entry_platform.dart';
import '../entry/entry_link_service.dart';
import '../entry/entry_outcome_router.dart';
import 'app_router.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'composition_root.dart';
import 'host_system_chrome.dart';

/// MOD-SHELL-001 — root widget wiring Core + settings into `MaterialApp.router`.
class AppPlayerApp extends StatefulWidget {
  const AppPlayerApp({super.key, required this.ctx});

  final AppContext ctx;

  @override
  State<AppPlayerApp> createState() => _AppPlayerAppState();
}

class _AppPlayerAppState extends State<AppPlayerApp> {
  late final AppLifecycleObserver _observer;
  late final GoRouter _router;
  EntryLinkService? _entryLinks;
  EntryController? _entryController;

  /// Set when this platform could not carry the entry across an install, so
  /// the chrome offers a way back instead of landing silently on home.
  final ValueNotifier<bool> _offerEntryRecovery = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _observer =
        AppLifecycleObserver(widget.ctx.core, logger: widget.ctx.logger)
          ..attach();
    // The debug host's `app.open` routes through this shell's router — a
    // harness reaches an installed bundle without registering it in the user's
    // app list, which would change the thing it is measuring.
    widget.ctx.core.debugOpenBundle = (bundleId) async {
      final router = _router;
      router.push('/app/$bundleId');
      return true;
    };
    _router = AppRouter.build(
      settings: widget.ctx.settings,
      entryRecoveryOffer: _offerEntryRecovery,
    );
    _startEntryLinks();
    _resumeDeferredEntry();
  }

  /// Entry links (platform spec 19 §9). Guarded because a build running
  /// without the platform channel — tests, an unsupported desktop target —
  /// must not lose its whole boot to a subscription it never needed.
  void _startEntryLinks() {
    try {
      _entryController = buildEntryController(logger: widget.ctx.logger);
      final service = EntryLinkService(
        controller: _entryController!,
        locale: () => widget.ctx.settings.locale.toLanguageTag(),
        logger: widget.ctx.logger,
      );
      _entryLinks = service;
      service.start(_onEntryOutcome);
    } catch (e) {
      widget.ctx.logger.warn('entry.links.unavailable', {'error': e.toString()});
    }
  }

  /// An entry that went through the store resumes here (§3.5). Resolution
  /// happens now, after the install — never from an answer minted before it,
  /// since custody may have changed while the store was busy.
  Future<void> _resumeDeferredEntry() async {
    try {
      final deferred = await DeferredEntryResolver(
        store: const PrefsFirstLaunchStore(),
        source: platformDeferredSource(),
        logger: widget.ctx.logger,
      ).onLaunch();

      switch (deferred.outcome) {
        case DeferredEntryOutcome.none:
          return;
        case DeferredEntryOutcome.offerRecovery:
          _offerEntryRecovery.value = true;
        case DeferredEntryOutcome.recovered:
          final controller = _entryController;
          if (controller == null || !deferred.hasCode) return;
          final outcome = await controller.handle(
            Uri.parse(
              'https://$kDemoEntryHost/e/${deferred.code}',
            ),
            locale: widget.ctx.settings.locale.toLanguageTag(),
          );
          if (!mounted) return;
          if (!routeEntryOutcome(_router, outcome)) {
            // The code survived but no longer resolves for us. Saying so
            // beats a home screen that looks like the scan never happened.
            _offerEntryRecovery.value = true;
          }
      }
    } catch (e) {
      widget.ctx.logger.warn('entry.deferred.failed', {'error': e.toString()});
    }
  }

  void _onEntryOutcome(EntryOutcome outcome) {
    if (!mounted) return;
    routeEntryOutcome(_router, outcome);
  }

  @override
  void dispose() {
    _offerEntryRecovery.dispose();
    _entryLinks?.dispose();
    _observer.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<AppPlayerCoreService>.value(value: widget.ctx.core),
        // The scanner and the link listener share one controller: two
        // acquisition sources, one set of rules (§9.2).
        Provider<EntryController>.value(
          value: _entryController ?? buildEntryController(),
        ),
        ChangeNotifierProvider<AppSettings>.value(value: widget.ctx.settings),
        Provider<SharedPrefsServerStorage>.value(
            value: widget.ctx.serverStorage),
        Provider<SecureCredentialVault>.value(value: widget.ctx.credentialVault),
        Provider<ConsoleLogger>.value(value: widget.ctx.logger),
        ListenableProvider<LogBuffer>.value(value: widget.ctx.logBuffer),
        ListenableProvider<AppsRegistry<AppConfig>>.value(
          value: widget.ctx.appsRegistry,
        ),
      ],
      child: HostChromeBinder(
        controller: widget.ctx.hostBrightness,
        child: Consumer<AppSettings>(
        builder: (_, settings, __) {
          // Propagate log-level changes live.
          widget.ctx.logger.minLevel = settings.logLevel;
          S.setLocale(settings.locale.languageCode == 'auto'
              ? WidgetsBinding.instance.platformDispatcher.locale
              : settings.locale);
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'AppPlayer',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            locale: settings.locale.languageCode == 'auto'
                ? null
                : settings.locale,
            supportedLocales: const <Locale>[
              Locale('en'),
              Locale('ko'),
              Locale('ja'),
              Locale('zh'),
            ],
            localizationsDelegates: const <LocalizationsDelegate<Object?>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
            // Honour the global view-mode pin by
            // wrapping every route in a FormFactorScope whenever the
            // user has pinned a concrete class. `auto` leaves MediaQuery
            // as the resolver and the `FormFactor.of(context)` helper
            // falls back to window-width classification.
            builder: (ctx, child) {
              if (child == null) return const SizedBox();
              final pin = settings.defaultViewMode.toFormFactor();
              final content = pin == null
                  ? child
                  : FormFactorScope(formFactor: pin, child: child);
              // Wrap in the debug capture boundary when the Debug MCP host
              // is active (no-op pass-through otherwise) so screenshot /
              // tap / tree tools read from a stable RepaintBoundary.
              return widget.ctx.core.debugCaptureWrap(content);
            },
          );
        },
        ),
      ),
    );
  }
}
