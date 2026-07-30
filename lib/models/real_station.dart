class RealStation {
  final String code;
  final int hotelCount;
  final int roomsToday;
  final List<RealHotel> hotels;
  final List<RealStarBucket> starMix;
  final RealCmManualSplit cmManualSplit;
  final double fillPct;
  final int gapRooms;
  final String? blockUtil;

  const RealStation({
    required this.code,
    required this.hotelCount,
    required this.roomsToday,
    required this.hotels,
    this.starMix = const [],
    this.cmManualSplit = const RealCmManualSplit(),
    this.fillPct = 0,
    this.gapRooms = 0,
    this.blockUtil,
  });

  factory RealStation.fromJson(Map<String, dynamic> json) {
    final hotelsJson = (json['hotels'] as List?) ?? [];
    final starMixJson = (json['star_mix'] as List?) ?? [];
    final cmManualJson = json['cm_manual_split'] as Map<String, dynamic>?;

    return RealStation(
      code: json['location'] as String? ?? '',
      hotelCount: json['hotel_count'] as int? ?? 0,
      roomsToday: json['total_available_rooms'] as int? ?? 0,
      hotels: hotelsJson
          .cast<Map<String, dynamic>>()
          .map((h) => RealHotel.fromJson(h))
          .toList(),
      starMix: starMixJson
          .cast<Map<String, dynamic>>()
          .map((s) => RealStarBucket.fromJson(s))
          .toList(),
      cmManualSplit: cmManualJson != null
          ? RealCmManualSplit.fromJson(cmManualJson)
          : const RealCmManualSplit(),
      fillPct: (json['fill_pct'] as num?)?.toDouble() ?? 0,
      gapRooms: json['gap'] as int? ?? 0,
      blockUtil: json['block_util']?.toString(),
    );
  }

  String get cityLabel {
    if (hotels.isEmpty) return '?';
    return hotels.first.hotelCity;
  }

  int get soldOutCount => hotels.where((h) => h.availableRooms == 0).length;
}

class RealHotel {
  final int hotelId;
  final String hotelName;
  final String hotelCity;
  final int availableRooms;
  final bool anyStopsell;
  final String? starCategory;
  final String? hotelSource;
  final String? address;
  final String? phone;
  final String? email;
  const RealHotel({
    required this.hotelId,
    required this.hotelName,
    required this.hotelCity,
    required this.availableRooms,
    required this.anyStopsell,
    this.starCategory,
    this.hotelSource,
    this.address,
    this.phone,
    this.email,
  });
  factory RealHotel.fromJson(Map<String, dynamic> json) {
    return RealHotel(
      hotelId: json['hotel_id'] as int? ?? 0,
      hotelName: json['hotel_name'] as String? ?? 'Unknown Hotel',
      hotelCity: json['hotel_city'] as String? ?? '',
      availableRooms: json['available_rooms'] as int? ?? 0,
      anyStopsell: json['any_stopsell'] as bool? ?? false,
      starCategory: json['star_category'] as String?,
      hotelSource: json['hotel_source'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }
}

class RealStarBucket {
  final int stars;
  final int rooms;
  final int hotelCount;

  const RealStarBucket({
    required this.stars,
    required this.rooms,
    required this.hotelCount,
  });

  factory RealStarBucket.fromJson(Map<String, dynamic> json) {
    return RealStarBucket(
      stars: json['stars'] as int? ?? 0,
      rooms: json['rooms'] as int? ?? 0,
      hotelCount: json['hotel_count'] as int? ?? 0,
    );
  }
}

class RealCmManualSplit {
  final int cmHotelCount;
  final int manualHotelCount;
  final int unknownSourceHotelCount;
  final double cmPercent;
  final int cmRooms;
  final int manualRooms;

  const RealCmManualSplit({
    this.cmHotelCount = 0,
    this.manualHotelCount = 0,
    this.unknownSourceHotelCount = 0,
    this.cmPercent = 0,
    this.cmRooms = 0,
    this.manualRooms = 0,
  });

  factory RealCmManualSplit.fromJson(Map<String, dynamic> json) {
    return RealCmManualSplit(
      cmHotelCount: json['cm_hotel_count'] as int? ?? 0,
      manualHotelCount: json['manual_hotel_count'] as int? ?? 0,
      unknownSourceHotelCount:
      json['unknown_source_hotel_count'] as int? ?? 0,
      cmPercent: (json['cm_percent'] as num?)?.toDouble() ?? 0,
      cmRooms: json['cm_rooms'] as int? ?? 0,
      manualRooms: json['manual_rooms'] as int? ?? 0,
    );
  }

  int get totalKnown => cmHotelCount + manualHotelCount;
}