import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  Future<void> saveCredentials(int id, String email, String token, String name, String phone, String address) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('id', id.toString());
    await prefs.setString('email', email);
    await prefs.setString('name', name);
    await prefs.setString('token', token);
    await prefs.setString('phone', phone);
    await prefs.setString('address', address);
  }

  Future<Map<String, String?>> getCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('id');
    String? email = prefs.getString('email');
    String? token = prefs.getString('token');
    String? name = prefs.getString('name');
    String? phone = prefs.getString('phone');
    String? address = prefs.getString('address');
    return {
      'id': id,
      'email': email,
      'token': token,
      'name': name,
      'phone': phone,
      'address': address,
    };
  }

  Future<void> clearCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('id');
    await prefs.remove('email');
    await prefs.remove('token');
    await prefs.remove('name');
  }
}

// Usage example:
// final prefsService = SharedPreferencesService();
// await prefsService.saveCredentials(email, token);
// final credentials = await prefsService.getCredentials();
