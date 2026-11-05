import 'package:lolisnatcher/src/data/booru.dart';
import 'package:lolisnatcher/src/data/booru_item.dart';
import 'package:lolisnatcher/src/data/tag_type.dart';
import 'package:lolisnatcher/src/handlers/search_handler.dart';
import 'package:lolisnatcher/src/handlers/tag_handler.dart';
import 'package:lolisnatcher/src/utils/tools.dart';

/// 69 mod: file name template.
/// Placeholders: {booru} {id} {md5} {name} (original name without extension) {artist} {character}
/// {copyright} {tags} (first 5 tags) {rating} {tab} {date} (yyyy-mm-dd of download)
class Mod69Naming {
  Mod69Naming._();

  static const String placeholders =
      '{booru} {id} {md5} {name} {artist} {character} {copyright} {tags} {rating} {tab} {date}';

  static String _typed(BooruItem item, TagType type, int max) {
    final names = <String>[];
    for (final t in item.tagsList) {
      TagType tt = t.tagType;
      if (tt == TagType.none) {
        try {
          tt = TagHandler.instance.getTag(t.fullString).tagType;
        } catch (_) {}
      }
      if (tt == type) names.add(t.fullString);
      if (names.length >= max) break;
    }
    return names.join(', ');
  }

  /// Returns null when [template] is empty (use the app's normal name).
  static String? build(String template, BooruItem item, Booru booru, String originalName) {
    final t = template.trim();
    if (t.isEmpty) return null;
    final dot = originalName.lastIndexOf('.');
    final base = dot > 0 ? originalName.substring(0, dot) : originalName;
    final ext = item.fileExt ?? (dot > 0 ? originalName.substring(dot + 1) : '');
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final values = <String, String>{
      'booru': booru.name ?? '',
      'id': item.serverId ?? '',
      'md5': item.md5String ?? '',
      'name': base.replaceFirst(RegExp('^${RegExp.escape(booru.name ?? '')}_'), ''),
      'artist': _typed(item, TagType.artist, 3),
      'character': _typed(item, TagType.character, 3),
      'copyright': _typed(item, TagType.copyright, 2),
      'tags': item.tagsList.take(5).map((e) => e.fullString).join(' '),
      'rating': item.rating ?? '',
      'tab': SearchHandler.instance.currentTabOrNull?.tags ?? '',
      'date': '${now.year}-${two(now.month)}-${two(now.day)}',
    };
    String out = t.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => values[m.group(1)] ?? m.group(0)!);
    out = out.replaceAll(':', '_');
    out = Tools.sanitize(out).replaceAll(RegExp(r'\s+'), ' ').trim();
    // tidy leftovers of empty placeholders like "_ _" or "[]"
    out = out.replaceAll(RegExp(r'\[\s*\]|\(\s*\)'), '').replaceAll(RegExp(r'[_\- ]{2,}'), '_').trim();
    if (out.length > 150) out = out.substring(0, 150).trim();
    if (out.isEmpty) return null;
    return ext.isEmpty ? out : '$out.$ext';
  }
}
