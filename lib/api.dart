import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Same live backend that the website uses.
const String kBaseUrl = 'https://purulia.lifelineapp.in';

class ApiError implements Exception {
  final String message;
  final int status;
  ApiError(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class Api {
  Api._();
  static final Api i = Api._();

  String? token;
  String? pendingMsg; // shown on the login screen after a forced logout
  void Function()? onUnauthorized;

  Future<void> loadToken() async {
    try {
      final p = await SharedPreferences.getInstance();
      token = p.getString('ll_token');
    } catch (_) {}
  }

  Future<void> saveToken(String? t) async {
    token = t; // always keep it in memory so login works even if saving to disk fails
    try {
      final p = await SharedPreferences.getInstance();
      if (t == null) {
        await p.remove('ll_token');
      } else {
        await p.setString('ll_token', t);
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> call(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$kBaseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 13) LifelineCustomerApp/1.0',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    http.Response r;
    try {
      if (body != null) {
        headers['Content-Type'] = 'application/json';
        r = await http
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 25));
      } else {
        r = await http.get(uri, headers: headers).timeout(const Duration(seconds: 25));
      }
    } catch (e) {
      final t = e.runtimeType.toString();
      throw ApiError(t.contains('Timeout')
          ? 'Server is taking too long. Check internet and try again.'
          : 'Network problem ($t). Check internet and try again.');
    }
    Map<String, dynamic> j = {};
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is Map<String, dynamic>) j = d;
    } catch (_) {}
    if (r.statusCode == 401 && !path.contains('login') && !path.contains('signup')) {
      pendingMsg = 'Session problem (401) on ${path.split('?').first}: ${(j['error'] ?? 'unauthorized')}. Please login again.';
      onUnauthorized?.call();
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw ApiError((j['error'] ?? 'Server problem (HTTP ${r.statusCode}). Please try again.').toString(), r.statusCode);
    }
    return j;
  }

  // ---- customer ----
  Future<Map<String, dynamic>> signup(String name, String mobile, String location, String pin) =>
      call('/api/customer?action=signup',
          body: {'name': name, 'mobile': mobile, 'location': location, 'pin': pin});

  Future<Map<String, dynamic>> login(String mobile, String pin) =>
      call('/api/customer?action=login', body: {'mobile': mobile, 'pin': pin});

  Future<Map<String, dynamic>> me() => call('/api/customer?action=me');

  Future<Map<String, dynamic>> updateProfile(String name, String location) =>
      call('/api/customer?action=profile', body: {'name': name, 'location': location});

  // ---- catalog & bookings ----
  Future<List<dynamic>> catalog() async {
    final j = await call('/api/catalog');
    return (j['catalog'] as List?) ?? [];
  }

  Future<List<Map<String, dynamic>>> myBookings() async {
    final j = await call('/api/booking?action=mine');
    return ((j['bookings'] as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> createBooking(Map<String, dynamic> data) =>
      call('/api/booking?action=create', body: data);

  Future<void> acceptBid(String id, String techId) =>
      call('/api/booking?action=acceptBid', body: {'id': id, 'techId': techId});

  Future<void> complete(String id) => call('/api/booking?action=complete', body: {'id': id, 'reason': ''});

  Future<void> cancel(String id, String reason) =>
      call('/api/booking?action=cancel', body: {'id': id, 'reason': reason});

  Future<void> feedback(String id, String satisfaction, int stars, String remark) =>
      call('/api/booking?action=feedback',
          body: {'id': id, 'satisfaction': satisfaction, 'stars': stars, 'remark': remark});
}
