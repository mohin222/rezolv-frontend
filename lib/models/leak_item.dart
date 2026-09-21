class LeakItem {
  final int hotelId;
  final String hotelName;
  final String station;
  final String date;
  final int cmRooms;
  final int extranetRooms;
  final int gap;
  final String address;
  final String phone;
  final String email;
  final double? distanceKm;
  final String? distanceText;
  final int? starCategory;
  final int? target;
  final int? starTargetPct;

  const LeakItem({
    required this.hotelId,
    required this.hotelName,
    required this.station,
    required this.date,
    required this.cmRooms,
    required this.extranetRooms,
    required this.gap,
    required this.address,
    required this.phone,
    required this.email,
    this.distanceKm,
    this.distanceText,
    this.starCategory,
    this.target,
    this.starTargetPct,
  });

  factory LeakItem.fromJson(Map<String, dynamic> j) {
    final rawDistance = j['distance'];
    return LeakItem(
      hotelId:       j['hotelId'] as int? ?? 0,
      hotelName:     j['hotelName'] as String? ?? '',
      station:       j['station'] as String? ?? '',
      date:          j['date'] as String? ?? '',
      cmRooms:       j['cmRooms'] as int? ?? 0,
      extranetRooms: j['extranetRooms'] as int? ?? 0,
      gap:           j['gap'] as int? ?? 0,
      address:       j['address'] as String? ?? '',
      phone:         j['phone'] as String? ?? '',
      email:         j['email'] as String? ?? '',
      distanceKm:    rawDistance is num ? rawDistance.toDouble() : null,
      distanceText:  rawDistance is String ? rawDistance : null,
      starCategory:  j['star_category'] as int?,
      target:        j['target'] as int?,
      starTargetPct: j['star_target_pct'] as int?,
    );
  }
}