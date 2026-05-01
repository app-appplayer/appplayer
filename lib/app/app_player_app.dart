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
import 'app_router.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'composition_root.dart';

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

  @override
  void initState() {
    super.initState();
    _observer =
        AppLifecycleObserver(widget.ctx.core, logger: widget.ctx.logger)
          ..attach();
    _router = AppRouter.build(
      onboardingCompleted: widget.ctx.settings.onboardingCompleted,
    );
  }

  @override
  void dispose() {
    _observer.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<AppPlayerCoreService>.value(value: widget.ctx.core),
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
            // Honour the global view-mode pin (plan §4 rung 2) by
            // wrapping every route in a FormFactorScope whenever the
            // user has pinned a concrete class. `auto` leaves MediaQuery
            // as the resolver and the `FormFactor.of(context)` helper
            // falls back to window-width classification.
            builder: (ctx, child) {
              final pin = settings.defaultViewMode.toFormFactor();
              if (pin == null || child == null) return child ?? const SizedBox();
              return FormFactorScope(formFactor: pin, child: child);
            },
          );
        },
      ),
    );
  }
}
