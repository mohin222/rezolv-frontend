import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'offline_cache.dart';
import '../models/real_station.dart';
import '../models/real_hotel_days.dart';
import '../models/leak_item.dart';

class UnauthorizedException implements Exception {}

class ApiRepository {
  Future<Map<String, String>> _headers() async {
    final token = await ApiConfig.getToken();
    return {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
    };
  }

  Future<T> _withRetry<T>(Future<T> Function() action, {int maxAttempts = 3}) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e) {
        lastError = e;
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 800 * attempt));
        }
      }
    }
    throw lastError!;
  }

  void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) throw UnauthorizedException();
  }

  Future<Map<String, String>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'token':    data['token']    ?? '',
        'username': data['username'] ?? '',
        'email':    data['email']    ?? '',
        'phone':    data['phone']    ?? '',
      };
    }
    throw Exception('Login failed (HTTP ${response.statusCode}): ${response.body}');
  }

  Future<Map<String, String>> verifyToken() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/verify/'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'username': data['username'] ?? '',
        'email':    data['email']    ?? '',
        'phone':    data['phone']    ?? '',
      };
    }
    throw UnauthorizedException();
  }

  Future<void> saveFcmToken(String fcmToken) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/fcm-token/');
      await http.post(
        uri,
        headers: await _headers(),
        body: jsonEncode({'fcm_token': fcmToken}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// Returns (stations, wasFromCache) — the cache flag describes only this
  /// specific call, never a value left over from some other screen's fetch.
  Future<(List<RealStation>, bool)> fetchAllStations({
    String? fromDate,
    String? toDate,
    String? station,
  }) async {
    try {
      final stationsJson = await _withRetry(() async {
        final now = DateTime.now();
        final defaultDate =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final from = fromDate ?? defaultDate;
        final to   = toDate   ?? defaultDate;

        final params = <String, String>{
          'from_date': from,
          'to_date':   to,
          if (station != null && station.isNotEmpty) 'station': station,
        };

        final uri = Uri.parse('${ApiConfig.baseUrl}/api/stations/')
            .replace(queryParameters: params);
        final response = await http.get(uri, headers: await _headers())
            .timeout(const Duration(seconds: 60));
        _checkUnauthorized(response);
        if (response.statusCode != 200) {
          throw Exception('Failed to load stations (status ${response.statusCode})');
        }
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return (decoded['stations'] as List).cast<Map<String, dynamic>>();
      });
      await OfflineCache.save('stations', stationsJson);
      return (stationsJson.map((json) => RealStation.fromJson(json)).toList(), false);
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      final cached = await OfflineCache.load('stations');
      if (cached is List) {
        return (cached.cast<Map<String, dynamic>>().map((json) => RealStation.fromJson(json)).toList(), true);
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAirportCodes() async {
    try {
      final codes = await _withRetry(() async {
        final uri = Uri.parse('${ApiConfig.baseUrl}/api/airport-codes/');
        final response = await http.get(uri, headers: await _headers())
            .timeout(const Duration(seconds: 30));
        _checkUnauthorized(response);
        if (response.statusCode != 200) throw Exception('Failed to load airport codes');
        return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
      });
      await OfflineCache.save('airport_codes', codes);
      return codes;
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      final cached = await OfflineCache.load('airport_codes');
      if (cached is List) return cached.cast<Map<String, dynamic>>();
      rethrow;
    }
  }

  Future<(List<String>, List<RealHotelDays>)> fetchStationDays(
      String locationCode, {
        String? fromDate,
        String? toDate,
      }) async {
    final cacheKey = 'station_days_$locationCode';
    try {
      final decoded = await _withRetry(() async {
        final now = DateTime.now();
        final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final sevenDaysLater = now.add(const Duration(days: 6));
        final sevenStr = '${sevenDaysLater.year}-${sevenDaysLater.month.toString().padLeft(2, '0')}-${sevenDaysLater.day.toString().padLeft(2, '0')}';
        final params = <String, String>{
          'from_date': fromDate ?? todayStr,
          'to_date': toDate ?? sevenStr,
        };
        final uri = Uri.parse('${ApiConfig.baseUrl}/api/inventory/$locationCode/')
            .replace(queryParameters: params);
        final response = await http.get(uri, headers: await _headers())
            .timeout(const Duration(seconds: 60));
        _checkUnauthorized(response);
        if (response.statusCode != 200) {
          throw Exception('Failed to load $locationCode (status ${response.statusCode})');
        }
        return jsonDecode(response.body) as Map<String, dynamic>;
      });
      await OfflineCache.save(cacheKey, decoded);
      final dates = (decoded['dates'] as List).cast<String>();
      final hotelsJson = (decoded['hotels_by_day'] as List).cast<Map<String, dynamic>>();
      final hotels = hotelsJson.map((h) => RealHotelDays.fromJson(h)).toList();
      return (dates, hotels);
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      final cached = await OfflineCache.load(cacheKey);
      if (cached is Map) {
        final decoded = cached.cast<String, dynamic>();
        final dates = (decoded['dates'] as List).cast<String>();
        final hotelsJson = (decoded['hotels_by_day'] as List).cast<Map<String, dynamic>>();
        final hotels = hotelsJson.map((h) => RealHotelDays.fromJson(h)).toList();
        return (dates, hotels);
      }
      rethrow;
    }
  }

  /// Returns (leaks, wasFromCache) — the cache flag describes only this
  /// specific call, never a value left over from some other screen's fetch.
  Future<(List<LeakItem>, bool)> fetchLeaks({
    required String date,
    String station = '',
    String hotelId = '',
    String hotelName = '',
  }) async {
    try {
      final leaksJson = await _withRetry(() async {
        final params = <String, String>{'date': date};
        if (station.isNotEmpty)   params['station']    = station;
        if (hotelId.isNotEmpty)   params['hotel_id']   = hotelId;
        if (hotelName.isNotEmpty) params['hotel_name'] = hotelName;
        final uri = Uri.parse('${ApiConfig.baseUrl}/api/leaks/')
            .replace(queryParameters: params);
        final response = await http.get(uri, headers: await _headers())
            .timeout(const Duration(seconds: 60));
        _checkUnauthorized(response);
        if (response.statusCode != 200) throw Exception('Failed to load leaks');
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['leaks'] as List).cast<Map<String, dynamic>>();
      });
      await OfflineCache.save('leaks', leaksJson);
      return (leaksJson.map((e) => LeakItem.fromJson(e)).toList(), false);
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      final cached = await OfflineCache.load('leaks');
      if (cached is List) {
        return (cached.cast<Map<String, dynamic>>().map((e) => LeakItem.fromJson(e)).toList(), true);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchTransportationStationDetail(String code) async {
    final cacheKey = 'transportation_station_$code';
    try {
      final data = await _withRetry(() async {
        final uri = Uri.parse('${ApiConfig.baseUrl}/api/transportation/station/$code/');
        final response = await http.get(uri, headers: await _headers())
            .timeout(const Duration(seconds: 30));
        _checkUnauthorized(response);
        if (response.statusCode != 200) throw Exception('Failed to load station detail');
        return jsonDecode(response.body) as Map<String, dynamic>;
      });
      await OfflineCache.save(cacheKey, data);
      return data;
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      final cached = await OfflineCache.load(cacheKey);
      if (cached is Map) return cached.cast<String, dynamic>();
      return {'code': code, 'vendors': [], 'vehicles': []};
    }
  }

  Future<Map<String, dynamic>> fetchTransportationDashboard() async {
    try {
      final data = await _withRetry(() async {
        final uri = Uri.parse('${ApiConfig.baseUrl}/api/transportation/dashboard/');
        final response = await http.get(uri, headers: await _headers())
            .timeout(const Duration(seconds: 30));
        _checkUnauthorized(response);
        if (response.statusCode != 200) throw Exception('Failed to load dashboard');
        return jsonDecode(response.body) as Map<String, dynamic>;
      });
      await OfflineCache.save('transportation_dashboard', data);
      return data;
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      final cached = await OfflineCache.load('transportation_dashboard');
      if (cached is Map) return cached.cast<String, dynamic>();
      return {'vehicle_types': {}, 'active_vendors': 0, 'fleet_vehicles': 0, 'active_drivers': 0};
    }
  }

  Future<List<Map<String, dynamic>>> fetchTransportationOverview() async {
    try {
      final stations = await _withRetry(() async {
        final uri = Uri.parse('${ApiConfig.baseUrl}/api/transportation/overview/');
        final response = await http.get(uri, headers: await _headers())
            .timeout(const Duration(seconds: 30));
        _checkUnauthorized(response);
        if (response.statusCode != 200) throw Exception('Failed to load transportation overview');
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['stations'] as List).cast<Map<String, dynamic>>();
      });
      await OfflineCache.save('transportation_overview', stations);
      return stations;
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      final cached = await OfflineCache.load('transportation_overview');
      if (cached is List) return cached.cast<Map<String, dynamic>>();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchDashboardSummary(String period, {String? station, String? airline}) async {
    final cacheKey = 'dashboard_summary_${period}_${station ?? 'all'}_${airline ?? 'all'}';
    try {
      final data = await _withRetry(() async {
        final uri = Uri.parse('${ApiConfig.baseUrl}/api/dashboard/summary/')
            .replace(queryParameters: {
              'period': period,
              if (station != null && station.isNotEmpty) 'station': station,
              if (airline != null && airline.isNotEmpty) 'airline': airline,
            });
        final response = await http.get(uri, headers: await _headers())
            .timeout(const Duration(seconds: 60));
        _checkUnauthorized(response);
        if (response.statusCode != 200) throw Exception('Failed to load dashboard summary');
        return jsonDecode(response.body) as Map<String, dynamic>;
      });
      await OfflineCache.save(cacheKey, data);
      return data;
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      final cached = await OfflineCache.load(cacheKey);
      if (cached is Map) return cached.cast<String, dynamic>();
      return {'total_available_rooms': 0, 'star_mix': [], 'top_hotels': [], 'from_date': '', 'to_date': ''};
    }
  }

  Future<List<Map<String, dynamic>>> fetchAirlines() async {
    try {
      final airlines = await _withRetry(() async {
        final uri = Uri.parse('${ApiConfig.baseUrl}/api/airlines/');
        final response = await http.get(uri, headers: await _headers())
            .timeout(const Duration(seconds: 30));
        _checkUnauthorized(response);
        if (response.statusCode != 200) throw Exception('Failed to load airlines');
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return (decoded['airlines'] as List).cast<Map<String, dynamic>>();
      });
      await OfflineCache.save('airlines', airlines);
      return airlines;
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      final cached = await OfflineCache.load('airlines');
      if (cached is List) return cached.cast<Map<String, dynamic>>();
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchFlightRiskLatest() async {
    try {
      final data = await _withRetry(() async {
        final uri = Uri.parse('${ApiConfig.baseUrl}/api/flight-risk/latest/');
        final response = await http.get(uri, headers: await _headers())
            .timeout(const Duration(seconds: 30));
        _checkUnauthorized(response);
        if (response.statusCode != 200) throw Exception('Failed to load flight risk summary');
        return jsonDecode(response.body) as Map<String, dynamic>;
      });
      await OfflineCache.save('flight_risk_latest', data);
      return data;
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      final cached = await OfflineCache.load('flight_risk_latest');
      if (cached is Map) return cached.cast<String, dynamic>();
      return {'uploaded_at': null, 'total_rows': 0, 'tomorrow_count': 0, 'next_5_days_count': 0};
    }
  }
}