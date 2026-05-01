/// MCP UI DSL 1.3 compliant theme for the showcase app.
///
/// Default `mode: 'system'` so the launcher's light/dark setting drives the
/// active scheme. Matches the canonical 14-domain shape from
/// `specs/mcp_ui_dsl/05_Theme.md` — Material 3 28-role color, 15-role
/// typography, 9-step spacing on the 8pt grid, 7-family shape, 6-level
/// elevation. Mode-specific overrides live under `light` / `dark`.
Map<String, dynamic> showcaseTheme() => {
      'mode': 'system',
      'color': {
        'seed': '#2196F3',
      },
      'light': {
        'mode': 'light',
        'color': {
          'primary': '#2196F3',
          'onPrimary': '#FFFFFF',
          'secondary': '#FF4081',
          'onSecondary': '#FFFFFF',
          'surface': '#F5F5F5',
          'onSurface': '#212121',
          'error': '#F44336',
          'onError': '#FFFFFF',
          'outlineVariant': '#E0E0E0',
        },
      },
      'dark': {
        'mode': 'dark',
        'color': {
          'primary': '#64B5F6',
          'onPrimary': '#000000',
          'secondary': '#FF80AB',
          'onSecondary': '#000000',
          'surface': '#1E1E1E',
          'onSurface': '#E0E0E0',
          'error': '#EF5350',
          'onError': '#000000',
          'outlineVariant': '#373737',
        },
      },
      'typography': {
        'headlineMedium': {'fontSize': 28, 'fontWeight': 'bold'},
        'titleLarge': {'fontSize': 22, 'fontWeight': 'bold'},
        'titleMedium': {'fontSize': 18, 'fontWeight': 'bold'},
        'bodyLarge': {'fontSize': 16, 'fontWeight': 'regular'},
        'bodyMedium': {'fontSize': 14, 'fontWeight': 'regular'},
        'bodySmall': {'fontSize': 12, 'fontWeight': 'regular'},
      },
      'spacing': {'sm': 8, 'md': 16, 'lg': 24},
      'shape': {'small': 4, 'medium': 8, 'large': 16},
    };
