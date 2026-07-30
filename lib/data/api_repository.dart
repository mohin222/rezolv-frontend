import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
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
    throw Exception('Invalid credentials');
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

  Future<List<RealStation>> fetchAllStations({
    String? fromDate,
    String? toDate,
    String? station,
  }) {
    return _withRetry(() async {
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
          .timeout(const Duration(seconds: 30));
      _checkUnauthorized(response);
      if (response.statusCode != 200) {
        throw Exception('Failed to load stations (status ${response.statusCode})');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final stationsJson = (decoded['stations'] as List).cast<Map<String, dynamic>>();
      return stationsJson.map((json) => RealStation.fromJson(json)).toList();
    });
  }

  Future<List<Map<String, dynamic>>> fetchAirportCodes() {
    return _withRetry(() async {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/airport-codes/');
      final response = await http.get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 30));
      _checkUnauthorized(response);
      if (response.statusCode != 200) throw Exception('Failed to load airport codes');
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    });
  }

  Future<(List<String>, List<RealHotelDays>)> fetchStationDays(
      String locationCode, {
        String? fromDate,
        String? toDate,
      }) {
    return _withRetry(() async {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final sevenDaysLater = now.add(const Duration(days: 6));
      final sevenStr = '${sevenDaysLater.year}-${sevenDaysLater.month.toString().padLeft(2, '0')}-${sevenDaysLater.day.toString().padLeft(2, '0')}';
      final params = <String, String>{
        'from_date': todayStr,
        'to_date': sevenStr,
      };
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/inventory/$locationCode/')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 30));
      _checkUnauthorized(response);
      if (response.statusCode != 200) {
        throw Exception('Failed to load $locationCode (status ${response.statusCode})');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final dates = (decoded['dates'] as List).cast<String>();
      final hotelsJson = (decoded['hotels_by_day'] as List).cast<Map<String, dynamic>>();
      final hotels = hotelsJson.map((h) => RealHotelDays.fromJson(h)).toList();
      return (dates, hotels);
    });
  }

  Future<List<LeakItem>> fetchLeaks({
    required String date,
    String station = '',
    String hotelId = '',
    String hotelName = '',
  }) {
    return _withRetry(() async {
      final params = <String, String>{'date': date};
      if (station.isNotEmpty)   params['station']    = station;
      if (hotelId.isNotEmpty)   params['hotel_id']   = hotelId;
      if (hotelName.isNotEmpty) params['hotel_name'] = hotelName;
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/leaks/')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 30));
      _checkUnauthorized(response);
      if (response.statusCode != 200) throw Exception('Failed to load leaks');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['leaks'] as List)
          .cast<Map<String, dynamic>>()
          .map((e) => LeakItem.fromJson(e))
          .toList();
    });
  }
}