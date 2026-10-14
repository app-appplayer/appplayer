import 'package:flutter/material.dart';

/// A folder on the home grid: a square the size of an app icon holding up to
/// four of its apps' icons, and the folder's name under it. Sized by the app
/// so it lines up with that app's own tiles.
class AppFolderTile extends StatelessWidget {
  const AppFolderTile({
    super.key,
    required this.name,
    required this.previews,
    required this.onTap,
    this.onContextMenu,
    this.width = 64,
    this.height,
    this.iconSize = 48,
    this.radius = 12,
    this.padding = const EdgeInsets.all(4),
    this.maxLines = 2,
    this.labelStyle,
  });

  final String name;

  /// Icons of the folder's first apps; the first four are shown.
  final List<Widget> previews;
  final VoidCallback onTap;

  /// Long-press and secondary click, with the tile as the anchor.
  final void Function(BuildContext anchor)? onContextMenu;
  final double width;
  final double? height;
  final double iconSize;
  final double radius;
  final EdgeInsetsGeometry padding;
  final int maxLines;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shown = previews.take(4).toList();
    const gap = 3.0;
    final inset = iconSize * 0.12;
    final cell = (iconSize - inset * 2 - gap) / 2;
    final menu = onContextMenu;
    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        onSecondaryTap: menu == null ? null : () => menu(context),
        child: InkWell(
          onTap: onTap,
          onLongPress: menu == null ? null : () => menu(context),
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: padding,
            child: Column(
              // A fixed-height tile centres like the app tiles beside it.
              mainAxisSize:
                  height == null ? MainAxisSize.min : MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: iconSize,
                  height: iconSize,
                  padding: EdgeInsets.all(inset),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: <Widget>[
                      for (final p in shown)
                        SizedBox.square(
                          dimension: cell,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(radius / 3),
                            child: FittedBox(child: p),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: maxLines,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle ?? Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
