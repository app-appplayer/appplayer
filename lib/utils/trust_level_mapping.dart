import 'package:appplayer_core/appplayer_core.dart' show TrustLevel;

import '../models/app_config.dart';

/// Maps the launcher-owned [AppTrustLevel] (persisted in `apps.v1`) to
/// the runtime's [TrustLevel] enum. The two enums are intentionally
/// separate — the launcher's persistence format must not carry a
/// runtime dependency — but their order is kept 1:1 so index mapping
/// is safe.
TrustLevel toRuntimeTrustLevel(AppTrustLevel level) {
  return TrustLevel.values[level.index];
}
