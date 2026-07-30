class RealHotelDays {
  final int hotelId;
  final String hotelName;
  final String hotelCity;
  final String? starCategory;
  final String? hotelSource;
  final String? address;
  final String? phone;
  final String? email;
  final Map<String, int> daysAvailability;
  final Map<String, Map<String, int>> dailySplit;

  const RealHotelDays({
    required this.hotelId,
    required this.hotelName,
    required this.hotelCity,
    required this.daysAvailability,
    this.starCategory,
    this.hotelSource,
    this.address,
    this.phone,
    this.email,
    this.dailySplit = const {},
  });

  factory RealHotelDays.fromJson(Map<String, dynamic> json) {
    final daysJson = (json['days'] as Map<String, dynamic>?) ?? {};
    final splitJson = (json['daily_split'] as Map<String, dynamic>?) ?? {};

    return RealHotelDays(
      hotelId: json['hotel_id'] as int? ?? 0,
      hotelName: json['hotel_name'] as String? ?? 'Unknown Hotel',
      hotelCity: json['hotel_city'] as String? ?? '',
      starCategory: json['star_category'] as String?,
      hotelSource: json['hotel_source'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      daysAvailability:
      daysJson.map((k, v) => MapEntry(k, v as int? ?? 0)),
      dailySplit: splitJson.map((k, v) {
        final inner = v as Map<String, dynamic>? ?? {};
        return MapEntry(k, {
          'cm': inner['cm'] as int? ?? 0,
          'extranet': inner['extranet'] as int? ?? 0,
        });
      }),
    );
  }

  int get stars {
    if (starCategory == null) return 0;
    return int.tryParse(starCategory!) ?? 0;
  }

  bool get anyStopsell => false;

  int? roomsFor(String dateStr) => daysAvailability[dateStr];

  int cmFor(String dateStr) => dailySplit[dateStr]?['cm'] ?? 0;
  int extranetFor(String dateStr) => dailySplit[dateStr]?['extranet'] ?? 0;
}