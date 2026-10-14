# app_folders — vendored

Copy of `os/core/brain_kernel/recipes/app_folders/lib`. Standard vendors rather
than path-depends (user decision 2026-08-06): this tier ships from a public
repository, and a path dependency reaching outside it would not resolve for
anyone who checked that repository out.

Re-sync by copying the recipe's `lib/` here. The recipe is the source; edits
belong there, not here.
