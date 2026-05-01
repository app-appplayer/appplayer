import 'package:appplayer/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light theme uses material3 and seed color scheme', () {
    final t = AppTheme.light();
    expect(t.useMaterial3, isTrue);
    expect(t.brightness, Brightness.light);
  });

  test('dark theme uses dark brightness', () {
    final t = AppTheme.dark();
    expect(t.useMaterial3, isTrue);
    expect(t.brightness, Brightness.dark);
  });

  test('light and dark share seed colour', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();
    expect(light.colorScheme.primary, isNot(equals(dark.colorScheme.primary)));
    expect(AppTheme.seed, const Color(0xFF3F51B5));
  });
}
