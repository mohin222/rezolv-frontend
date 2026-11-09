import 'package:flutter/foundation.dart';
import '../data/api_repository.dart';
import '../models/peak_date.dart';
import '../models/room_block.dart';

/// Upcoming peak dates and room blocks, loaded with the Overview and shared
/// by the station cards (via Provider) so each card doesn't fetch its own.
class PeakDatesStore extends ChangeNotifier {
  /// A station card only shows a peak / block this close.
  static const cardWindowDays = 14;

  List<PeakDate> _items = [];
  List<RoomBlock> _blocks = [];
  List<PeakDate> get items => List.unmodifiable(_items);
  List<RoomBlock> get blocks => List.unmodifiable(_blocks);

  Future<void> load() async {
    // Independent — one failing keeps the other (and whatever loaded before).
    await Future.wait([
      ApiRepository().fetchPeakDates().then((v) => _items = v).catchError((_) => _items),
      ApiRepository().fetchRoomBlocks().then((v) => _blocks = v).catchError((_) => _blocks),
    ]);
    notifyListeners();
  }

  bool _soon(bool ongoing, int daysToGo) => ongoing || daysToGo <= cardWindowDays;

  /// Peaks for this station (including all-station dates) starting within
  /// [cardWindowDays] or already under way, nearest first.
  List<PeakDate> upcomingFor(String stationCode) => _items
      .where((p) => p.appliesTo(stationCode) && _soon(p.ongoing, p.daysToGo))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  /// All upcoming peaks / room blocks for one station (no 14-day window).
  List<PeakDate> allPeaksFor(String stationCode) =>
      _items.where((p) => p.appliesTo(stationCode)).toList()..sort((a, b) => a.start.compareTo(b.start));
  List<RoomBlock> allBlocksFor(String stationCode) => _blocks.where((b) => b.station == stationCode).toList();

  /// Room blocks at this station starting within [cardWindowDays] or under way.
  List<RoomBlock> blocksFor(String stationCode) => _blocks
      .where((b) => b.station == stationCode && _soon(b.ongoing, b.daysToGo))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));
}
