import 'package:appplayer/app/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSpacing scale is strictly increasing', () {
    test('xxs < xs < sm < md < base < lg < xl < xxl', () {
      final values = <double>[
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.base,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ];
      for (var i = 1; i < values.length; i++) {
        expect(values[i] > values[i - 1], isTrue,
            reason: 'expected ${values[i]} > ${values[i - 1]}');
      }
    });
  });

  group('AppRadii scale is strictly increasing', () {
    test('sm < md < lg < xl < full', () {
      expect(AppRadii.sm < AppRadii.md, isTrue);
      expect(AppRadii.md < AppRadii.lg, isTrue);
      expect(AppRadii.lg < AppRadii.xl, isTrue);
      expect(AppRadii.xl < AppRadii.full, isTrue);
    });

    test('BorderRadius mirrors the numeric tokens', () {
      expect(AppRadii.brSm, const BorderRadius.all(Radius.circular(AppRadii.sm)));
      expect(AppRadii.brMd, const BorderRadius.all(Radius.circular(AppRadii.md)));
      expect(AppRadii.brFull,
          const BorderRadius.all(Radius.circular(AppRadii.full)));
    });
  });

  group('AppElevation levels are non-decreasing', () {
    test('level0 ≤ 1 ≤ 2 ≤ 3 ≤ 4 ≤ 5', () {
      expect(AppElevation.level0 <= AppElevation.level1, isTrue);
      expect(AppElevation.level1 <= AppElevation.level2, isTrue);
      expect(AppElevation.level2 <= AppElevation.level3, isTrue);
      expect(AppElevation.level3 <= AppElevation.level4, isTrue);
      expect(AppElevation.level4 <= AppElevation.level5, isTrue);
    });
  });

  group('AppMotion durations are strictly increasing', () {
    test('fast < normal < slow < deliberate', () {
      expect(AppMotion.fast < AppMotion.normal, isTrue);
      expect(AppMotion.normal < AppMotion.slow, isTrue);
      expect(AppMotion.slow < AppMotion.deliberate, isTrue);
    });
  });

  group('AppIconSizes scale', () {
    test('sm < md < lg < xl', () {
      expect(AppIconSizes.sm < AppIconSizes.md, isTrue);
      expect(AppIconSizes.md < AppIconSizes.lg, isTrue);
      expect(AppIconSizes.lg < AppIconSizes.xl, isTrue);
    });
  });

  group('AppBreakpoints scale', () {
    test('compact ≤ medium ≤ expanded ≤ large ≤ extraLarge', () {
      expect(AppBreakpoints.compact <= AppBreakpoints.medium, isTrue);
      expect(AppBreakpoints.medium <= AppBreakpoints.expanded, isTrue);
      expect(AppBreakpoints.expanded <= AppBreakpoints.large, isTrue);
      expect(AppBreakpoints.large <= AppBreakpoints.extraLarge, isTrue);
    });
  });

  group('AppColors semantic accessors react to brightness', () {
    test('success light and dark variants differ', () {
      expect(AppColors.success(Brightness.light),
          isNot(equals(AppColors.success(Brightness.dark))));
    });

    test('warning light and dark variants differ', () {
      expect(AppColors.warning(Brightness.light),
          isNot(equals(AppColors.warning(Brightness.dark))));
    });

    test('info light and dark variants differ', () {
      expect(AppColors.info(Brightness.light),
          isNot(equals(AppColors.info(Brightness.dark))));
    });

    test('seed is the brand indigo', () {
      expect(AppColors.seed, const Color(0xFF3F51B5));
    });
  });
}
