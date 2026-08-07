# host_media — vendored

Copy of `os/core/brain_kernel/recipes/host_media`. Standard vendors rather than
path-depends (user decision 2026-08-06): this tier ships from a public
repository, and a path dependency reaching outside it would not resolve for
anyone who checked that repository out.

Re-sync by copying `lib/src/media_capabilities.dart` from the recipe. The recipe
is the source; edits belong there, not here.
