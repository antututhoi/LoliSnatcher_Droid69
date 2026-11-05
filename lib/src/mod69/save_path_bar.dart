import 'dart:io';

import 'package:flutter/material.dart';

import 'package:lolisnatcher/src/handlers/service_handler.dart';
import 'package:lolisnatcher/src/handlers/settings_handler.dart';
import 'package:lolisnatcher/src/handlers/snatch_handler.dart';

/// 69 mod: makes a storage uri / path readable, e.g. "Internal / Pictures / Loli".
String mod69ReadablePath(String raw) {
  if (raw.isEmpty) return 'Pictures (default)';
  String s = raw;
  if (s.startsWith('content://')) {
    final uri = Uri.tryParse(s);
    final segs = uri?.pathSegments ?? const <String>[];
    final treeAt = segs.indexOf('tree');
    String doc = treeAt >= 0 && treeAt + 1 < segs.length ? segs[treeAt + 1] : (segs.isNotEmpty ? segs.last : s);
    doc = Uri.decodeComponent(doc);
    final host = uri?.host ?? '';
    if (doc.startsWith('file://')) doc = doc.substring(7);
    if (doc.startsWith('primary:')) {
      doc = 'Internal/${doc.substring(8)}';
    } else if (host.contains('rclone') || host.contains('rsaf')) {
      doc = 'rclone: $doc';
    } else if (doc.contains(':') && !doc.startsWith('/')) {
      final i = doc.indexOf(':');
      doc = '${doc.substring(0, i)}/${doc.substring(i + 1)}';
    }
    s = doc;
  }
  s = s.replaceFirst(RegExp(r'^/storage/emulated/0'), 'Internal');
  return s.split('/').where((e) => e.isNotEmpty).join(' / ');
}

/// 69 mod: "Saving to …" with a quick Change button, shown at the top of the downloads drawer.
class Mod69SavePathBar extends StatefulWidget {
  const Mod69SavePathBar({super.key});

  @override
  State<Mod69SavePathBar> createState() => _Mod69SavePathBarState();
}

class _Mod69SavePathBarState extends State<Mod69SavePathBar> {
  final settings = SettingsHandler.instance;

  Future<void> _change() async {
    if (!Platform.isAndroid) return;
    final String newPath = await ServiceHandler.setExtDir();
    if (newPath.isEmpty) return;
    settings.extPathOverride = newPath;
    await settings.saveSettings(restate: false);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final folder = SnatchHandler.mod69FolderFor(null);
    final path = mod69ReadablePath(settings.extPathOverride);
    return Material(
      color: scheme.surfaceContainerHigh,
      child: InkWell(
        onTap: _change,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saving to', style: Theme.of(context).textTheme.labelSmall),
                    Text(
                      folder.isEmpty ? path : '$path / $folder',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: _change, child: const Text('Change')),
            ],
          ),
        ),
      ),
    );
  }
}
