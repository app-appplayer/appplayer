/// The grouping rule: an app is in at most one folder, named by the person.
/// A folder exists while it holds an app — there is nothing to create or
/// delete on its own.
library;

/// The folder name to store for what the person typed: trimmed, and null
/// (no folder) when nothing is left.
String? normalizeFolderName(String? raw) {
  final name = raw?.trim();
  return name == null || name.isEmpty ? null : name;
}

/// A home's apps split into folders and the apps outside any folder.
class FolderLayout<T> {
  const FolderLayout({required this.folders, required this.loose});

  /// Folder name → its apps, names in order (case-insensitive), apps in the
  /// order they came.
  final Map<String, List<T>> folders;

  /// Apps in no folder, in the order they came.
  final List<T> loose;

  /// Splits [apps] by [folderOf]. A blank folder counts as none.
  factory FolderLayout.of(Iterable<T> apps, String? Function(T app) folderOf) {
    final byName = <String, List<T>>{};
    final loose = <T>[];
    for (final app in apps) {
      final name = normalizeFolderName(folderOf(app));
      if (name == null) {
        loose.add(app);
      } else {
        byName.putIfAbsent(name, () => <T>[]).add(app);
      }
    }
    final names = byName.keys.toList()
      ..sort((a, b) {
        final c = a.toLowerCase().compareTo(b.toLowerCase());
        return c != 0 ? c : a.compareTo(b);
      });
    return FolderLayout<T>(
      folders: {for (final n in names) n: byName[n]!},
      loose: loose,
    );
  }

  /// Folder names, in order.
  List<String> get names => folders.keys.toList(growable: false);
}
