import 'package:flutter/foundation.dart';
import '../data/api_repository.dart';
import '../models/peak_date.dart';

/// Upcoming peak & block dates, loaded with the Overview and shared by the
/// station cards (via Provider) so each card doesn't fetch its own copy.
class PeakDatesStore extends ChangeNotifier {
  /// A station card only shows a peak this close.
  static const cardWindowDays = 14;

  List<PeakDate> _items = [];
  List<PeakDate> get items => List.unmodifiable(_items);

  Future<void> load() async {
    try {
      _items = await ApiRepository().fetchPeakDates();
      notifyListeners();
    } catch (_) {
      // Nice-to-have: keep whatever was loaded before.
    }
  }

  /// Peaks for this station (including all-station dates) starting within
  /// [cardWindowDays] or already under way, nearest first.
  List<PeakDate> upcomingFor(String stationCode) {
    return _items
        .where((p) => p.appliesTo(stationCode) && (p.ongoing || p.daysToGo <= cardWindowDays))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }
}
