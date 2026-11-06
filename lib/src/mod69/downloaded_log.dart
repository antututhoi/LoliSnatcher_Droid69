import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:lolisnatcher/src/data/booru.dart';
import 'package:lolisnatcher/src/data/booru_item.dart';
import 'package:lolisnatcher/src/handlers/booru_handler.dart';
import 'package:lolisnatcher/src/widgets/thumbnail/thumbnail_build.dart';

/// 69 mod: list of finished downloads, shown at the bottom of the downloads panel.
class Mod69Done {
  Mod69Done({
    required this.item,
    required this.booru,
    required this.name,
    this.oldSize,
    this.newSize,
  });

  final BooruItem item;
  final Booru booru;
  final String name;
  final int? oldSize;
  final int? newSize;

  String get format => name.contains('.') ? name.substring(name.lastIndexOf('.') + 1).toUpperCase() : '';
}

class Mod69DownloadedLog {
  Mod69DownloadedLog._();

  static final RxList<Mod69Done> items = RxList<Mod69Done>([]);

  /// Set by the native side right after 69-Media Helper converted the last file.
  static ({String name, int oldSize, int newSize})? lastProcessed;

  static void add(BooruItem item, Booru booru, String fileName) {
    final p = lastProcessed;
    lastProcessed = null;
    items.insert(
      0,
      Mod69Done(item: item, booru: booru, name: p?.name ?? fileName, oldSize: p?.oldSize, newSize: p?.newSize),
    );
    if (items.length > 300) items.removeRange(300, items.length);
  }

  static String size(int? b) {
    if (b == null || b <= 0) return '';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class Mod69DoneHeader extends StatelessWidget {
  const Mod69DoneHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => Text(
                'Downloaded (${Mod69DownloadedLog.items.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: Mod69DownloadedLog.items.clear,
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class Mod69DoneItem extends StatelessWidget {
  const Mod69DoneItem({
    required this.done,
    required this.handler,
    super.key,
  });

  final Mod69Done done;
  final BooruHandler handler;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final oldS = Mod69DownloadedLog.size(done.oldSize);
    final newS = Mod69DownloadedLog.size(done.newSize);
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 64,
            height: 84,
            child: ThumbnailBuild(
              item: done.item,
              handler: handler,
              selectable: false,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 4,
            children: [
              Text(done.name, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (done.format.isNotEmpty)
                    Chip(
                      label: Text(done.format),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  if (oldS.isNotEmpty && newS.isNotEmpty)
                    Chip(
                      label: Text('$oldS → $newS'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Mod69DownloadedLog.items.remove(done),
        ),
      ],
    );
  }
}
