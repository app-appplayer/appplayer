/// The words the folder parts show — each app passes its own, in its own
/// language.
class AppFolderLabels {
  const AppFolderLabels({
    required this.moveTitle,
    required this.newFolderHint,
    required this.move,
    required this.takeOut,
    required this.cancel,
    required this.rename,
    required this.renameTitle,
    required this.save,
  });

  /// Title of the move dialog ("Move to folder").
  final String moveTitle;

  /// Placeholder of the field that names a new folder ("New folder name").
  final String newFolderHint;

  /// Confirms the move ("Move").
  final String move;

  /// Takes the app out of its folder ("Take out of folder").
  final String takeOut;
  final String cancel;

  /// Tooltip of the folder screen's rename action ("Rename").
  final String rename;

  /// Title of the rename dialog ("Rename folder").
  final String renameTitle;
  final String save;
}
