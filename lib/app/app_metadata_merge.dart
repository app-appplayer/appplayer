import 'package:appplayer_core/appplayer_core.dart' show AppMetadata;

import '../models/app_config.dart';

/// What the app announces (`ui://app/info` · a bundle's manifest) written onto
/// its launcher entry, so the tile shows its icon and info without a second
/// fetch.
AppConfig mergeAppMetadata(AppConfig existing, AppMetadata m) =>
    existing.copyWith(
      // The announced name replaces only a name filled in automatically;
      // a given name stays (FR-ADAPT-006). Empty `m.name` (server omitted
      // ui://app/info) keeps the existing name.
      name: existing.nameIsAutomatic && m.name.trim().isNotEmpty
          ? m.name.trim()
          : null,
      iconUrl: m.iconUri,
      metadataJson: <String, dynamic>{
        'appId': m.appId,
        'sourceKind': m.sourceKind,
        'name': m.name,
        'version': m.version,
        if (m.description != null) 'description': m.description,
        if (m.iconUri != null) 'iconUri': m.iconUri,
        if (m.splashUri != null) 'splashUri': m.splashUri,
        if (m.screenshots.isNotEmpty) 'screenshots': m.screenshots,
        if (m.category != null) 'category': m.category,
        if (m.publisher != null) 'publisher': m.publisher,
        if (m.homepage != null) 'homepage': m.homepage,
        if (m.privacyPolicy != null) 'privacyPolicy': m.privacyPolicy,
        if (m.extra.isNotEmpty) 'extra': m.extra,
      },
    );
