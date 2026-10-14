import '../models/app_config.dart';
import 'app_strings.dart';

/// The text shown for [rating] in the person's language: `12+` and `17+` read
/// the same everywhere, "all ages" and "not rated" are words.
String ageRatingLabel(AgeRating rating) => switch (rating) {
      AgeRating.unrated => S.get('form.age.unrated'),
      AgeRating.everyone => S.get('age.all'),
      AgeRating.age12 || AgeRating.age17 => rating.label,
    };
