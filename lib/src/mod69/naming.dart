import 'package:intl/intl.dart';

import 'package:lolisnatcher/src/data/booru.dart';
import 'package:lolisnatcher/src/data/booru_item.dart';
import 'package:lolisnatcher/src/data/tag_type.dart';
import 'package:lolisnatcher/src/handlers/search_handler.dart';
import 'package:lolisnatcher/src/handlers/tag_handler.dart';

/// 69 mod: file name template. Works with Grabber style (%date% - %artist% - %md5%.%ext%)
/// and with {date} - {artist} - {md5}.
/// Names: booru, id, md5, name, artist, character, copyright, tags, rating, tab, date, ext
///  - date = when it was posted ("MM-dd-yyyy HH.mm", like Grabber), or today when the site gives no date
///  - artist = "anonymous" when there is none (like Grabber)
///  - copyright: when one name contains another, only the shorter one is kept (like Grabber)
class Mod69Naming {
  Mod69Naming._();

  static const String placeholders =
      '%date% %artist% %copyright% %character% %md5% %id% %booru% %name% %tags% %rating% %tab% %ext%  (or {date} …)';

  static List<String> _typed(BooruItem item, TagType type) {
    final names = <String>[];
    for (final t in item.tagsList) {
      TagType tt = t.tagType;
      if (tt == TagType.none) {
        try {
          tt = TagHandler.instance.getTag(t.fullString).tagType;
        } catch (_) {}
      }
      if (tt == type) names.add(t.fullString);
    }
    return names;
  }

  /// "queen's_blade queen's_blade_vanquished_queens" -> "queen's_blade"
  static List<String> _shorter(List<String> list) {
    final sorted = [...list]..sort((a, b) => a.length.compareTo(b.length));
    final out = <String>[];
    for (final c in sorted) {
      if (!out.any((k) => c.startsWith(k))) out.add(c);
    }
    return out;
  }

  static DateTime? _postDate(BooruItem item) {
    String d = item.postDate ?? '';
    final f = item.postDateFormat ?? '';
    if (d.isEmpty || f.isEmpty) return null;
    try {
      if (f == 'unix') return DateTime.fromMillisecondsSinceEpoch(int.parse(d) * 1000);
      d = d.replaceAll(RegExp(r'(?:\+|\-)\d{4}'), '');
      if (f == 'iso') return DateTime.parse(d).toLocal();
      return DateFormat(f).parseLoose(d).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Characters Android / SD cards do not allow in file names.
  static String _clean(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_');

  /// Returns null when [template] is empty (use the app's normal name).
  static String? build(String template, BooruItem item, Booru booru, String originalName) {
    String t = template.trim();
    if (t.isEmpty) return null;
    final dot = originalName.lastIndexOf('.');
    final base = dot > 0 ? originalName.substring(0, dot) : originalName;
    final ext = item.fileExt ?? (dot > 0 ? originalName.substring(dot + 1) : '');
    final date = _postDate(item) ?? DateTime.now();
    final artists = _typed(item, TagType.artist);
    final values = <String, String>{
      'booru': booru.name ?? '',
      'id': item.serverId ?? '',
      'md5': item.md5String ?? '',
      'name': base.replaceFirst(RegExp('^${RegExp.escape(booru.name ?? '')}_'), ''),
      'artist': artists.isEmpty ? 'anonymous' : _shorter(artists).take(3).join(' '),
      'character': _shorter(_typed(item, TagType.character)).take(3).join(' '),
      'copyright': _shorter(_typed(item, TagType.copyright)).take(2).join(' '),
      'tags': item.tagsList.take(5).map((e) => e.fullString).join(' '),
      'rating': item.rating ?? '',
      'tab': SearchHandler.instance.currentTabOrNull?.tags ?? '',
      'date': DateFormat('MM-dd-yyyy HH.mm').format(date),
      'ext': ext,
    };
    final bool hasExt = RegExp(r'(%ext%|\{ext\})\s*$').hasMatch(t);
    // %name% and {name}
    String out = t.replaceAllMapped(
      RegExp(r'%(\w+)%|\{(\w+)\}'),
      (m) {
        final key = (m.group(1) ?? m.group(2))!;
        final v = values[key];
        return v == null ? m.group(0)! : _clean(v);
      },
    );
    out = _clean(out);
    // empty values leave " -  - " behind: tidy those separators, keep everything else as typed
    out = out.replaceAll(RegExp(r'(\s*-\s*){2,}'), ' - ').replaceAll(RegExp(r'^\s*-\s*|\s*-\s*$'), '').trim();
    if (out.length > 180) out = out.substring(0, 180).trim();
    if (out.isEmpty || out == '.$ext') return null;
    if (hasExt || ext.isEmpty) return out;
    return '$out.$ext';
  }
}
