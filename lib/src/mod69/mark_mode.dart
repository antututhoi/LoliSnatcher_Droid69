import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:lolisnatcher/src/handlers/search_handler.dart';

/// 69 mod: item index attached to each thumbnail so a dragging finger can find it.
class Mod69ItemIndex {
  const Mod69ItemIndex(this.index);
  final int index;
}

/// 69 mod: mark mode for the grid.
/// - long press starts it (and marks the item), keep the finger down and drag to mark many
/// - in mark mode: tap = mark / unmark, long press = open the viewer with a big checkbox
/// - leave with back or the ✕ in the bar
class Mod69Mark {
  Mod69Mark._();

  static bool get active => SearchHandler.instance.currentSelectedOrNull?.isNotEmpty ?? false;

  static bool _dragging = false;
  static bool _dragAdd = true;
  static int? _lastIndex;
  static int? _startIndex;
  static final Set<int> _dragTouched = {};
  static Timer? _autoScroll;
  static double _autoScrollSpeed = 0;
  static Offset? _lastGlobal;

  static void toggle(int index) {
    final tab = SearchHandler.instance.currentTabOrNull;
    final fetched = SearchHandler.instance.currentFetchedOrNull;
    if (tab == null || fetched == null || index < 0 || index >= fetched.length) return;
    final item = fetched[index];
    if (tab.selected.contains(item)) {
      tab.selected.remove(item);
    } else {
      tab.selected.add(item);
    }
  }

  static void _set(int index, bool add) {
    final tab = SearchHandler.instance.currentTabOrNull;
    final fetched = SearchHandler.instance.currentFetchedOrNull;
    if (tab == null || fetched == null || index < 0 || index >= fetched.length) return;
    final item = fetched[index];
    final has = tab.selected.contains(item);
    if (add && !has) tab.selected.add(item);
    if (!add && has) tab.selected.remove(item);
  }

  static void clear() {
    SearchHandler.instance.currentTabOrNull?.selected.clear();
  }

  static void selectAll() {
    final tab = SearchHandler.instance.currentTabOrNull;
    final fetched = SearchHandler.instance.currentFetchedOrNull;
    if (tab == null || fetched == null) return;
    for (final item in fetched) {
      if (!tab.selected.contains(item)) tab.selected.add(item);
    }
  }

  /// Called right after a long press marked / unmarked [index]; the finger is still down.
  static void startDrag(int index) {
    final tab = SearchHandler.instance.currentTabOrNull;
    final fetched = SearchHandler.instance.currentFetchedOrNull;
    if (tab == null || fetched == null || index >= fetched.length) return;
    _dragging = true;
    _dragAdd = tab.selected.contains(fetched[index]);
    _startIndex = index;
    _lastIndex = index;
    _dragTouched
      ..clear()
      ..add(index);
  }

  static int? _indexAt(Offset global) {
    final result = HitTestResult();
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return null;
    WidgetsBinding.instance.hitTestInView(result, global, view.viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData && target.metaData is Mod69ItemIndex) {
        return (target.metaData as Mod69ItemIndex).index;
      }
    }
    return null;
  }

  static void _markRangeTo(int index) {
    final start = _startIndex;
    if (start == null) return;
    final lo = index < start ? index : start;
    final hi = index < start ? start : index;
    // mark everything between the first item and the finger; undo items the finger moved back over
    for (final i in _dragTouched.toList()) {
      if (i < lo || i > hi) {
        _set(i, !_dragAdd);
        _dragTouched.remove(i);
      }
    }
    for (int i = lo; i <= hi; i++) {
      if (_dragTouched.add(i)) _set(i, _dragAdd);
    }
  }

  static void onPointerMove(PointerMoveEvent e, ScrollController controller, double viewHeight, double topInset) {
    if (!_dragging) return;
    _lastGlobal = e.position;
    final idx = _indexAt(e.position);
    if (idx != null && idx != _lastIndex) {
      _lastIndex = idx;
      _markRangeTo(idx);
    }
    // scroll the grid when the finger is near the top or bottom edge
    const edge = 90.0;
    final y = e.position.dy;
    if (y < topInset + edge) {
      _autoScrollSpeed = -((topInset + edge - y) / edge * 24).clamp(4, 24);
    } else if (y > viewHeight - edge) {
      _autoScrollSpeed = ((y - (viewHeight - edge)) / edge * 24).clamp(4, 24);
    } else {
      _autoScrollSpeed = 0;
    }
    if (_autoScrollSpeed != 0 && _autoScroll == null) {
      _autoScroll = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (!controller.hasClients || _autoScrollSpeed == 0) return;
        final pos = controller.position;
        final next = (pos.pixels + _autoScrollSpeed).clamp(pos.minScrollExtent, pos.maxScrollExtent);
        if (next != pos.pixels) controller.jumpTo(next);
        final g = _lastGlobal;
        if (g != null) {
          final idx = _indexAt(g);
          if (idx != null && idx != _lastIndex) {
            _lastIndex = idx;
            _markRangeTo(idx);
          }
        }
      });
    } else if (_autoScrollSpeed == 0) {
      _autoScroll?.cancel();
      _autoScroll = null;
    }
  }

  static void endDrag() {
    _dragging = false;
    _startIndex = null;
    _lastIndex = null;
    _dragTouched.clear();
    _autoScroll?.cancel();
    _autoScroll = null;
    _autoScrollSpeed = 0;
  }
}

/// 69 mod: bar shown while marking: ✕ (leave), count, select all.
class Mod69MarkBar extends StatelessWidget {
  const Mod69MarkBar({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      elevation: 6,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Stop marking',
              icon: const Icon(Icons.close),
              color: scheme.onSecondaryContainer,
              onPressed: Mod69Mark.clear,
            ),
            Text(
              '$count marked',
              style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: Mod69Mark.selectAll,
              child: const Text('All'),
            ),
          ],
        ),
      ),
    );
  }
}
