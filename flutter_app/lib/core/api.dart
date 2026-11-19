part of '../main.dart';

class Api {
  static const storage = FlutterSecureStorage();
  static String? token;
  static Future<dynamic> request(String method, String path, [Map<String, dynamic>? data]) async {
    final uri = Uri.parse('$apiBase$path');
    final headers = <String, String>{'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
    late http.Response response;
    try {
      if (method == 'POST') {
        response = await http.post(uri, headers: headers, body: jsonEncode(data ?? {}));
      } else if (method == 'PUT') {
        response = await http.put(uri, headers: headers, body: jsonEncode(data ?? {}));
      } else if (method == 'DELETE') {
        response = await http.delete(uri, headers: headers);
      } else {
        response = await http.get(uri, headers: headers);
      }
    } catch (_) { throw Exception('Cannot reach server. Check API_BASE_URL and internet connection.'); }
    dynamic result;
    try { result = jsonDecode(response.body); } catch (_) { throw Exception('Invalid server response (${response.statusCode})'); }
    if (response.statusCode >= 400) throw Exception(result is Map ? result['error'] ?? 'Request failed' : 'Request failed');
    return result;
  }
  static Future<void> logout() async { token = null; await storage.delete(key: 'token'); }
}

