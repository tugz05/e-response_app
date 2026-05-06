import 'package:e_response_app_nemsu/helpers/account_session.dart';
import 'package:e_response_app_nemsu/helpers/app_mobile_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  Future<void> saveCredentials(
    int id,
    String email,
    String token,
    String name,
    String phone,
    String address,
    String accountStatus, {
    String firstName = '',
    String middleName = '',
    String lastName = '',
    String suffix = '',
    AppMobileRole appRole = AppMobileRole.citizen,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('id', id.toString());
    await prefs.setString('email', email);
    await prefs.setString('name', name);
    await prefs.setString('token', token);
    await prefs.setString('phone', phone);
    await prefs.setString('address', address);
    await prefs.setString('account_status', accountStatus);
    await prefs.setString('fname', firstName);
    await prefs.setString('mname', middleName);
    await prefs.setString('lname', lastName);
    await prefs.setString('suffix', suffix);
    await prefs.setString(AppMobileRole.prefsKey, appRole.apiValue);
  }

  Future<Map<String, String?>> getCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('id');
    String? email = prefs.getString('email');
    String? token = prefs.getString('token');
    String? name = prefs.getString('name');
    String? phone = prefs.getString('phone');
    String? address = prefs.getString('address');
    String? accountStatus = prefs.getString('account_status');
    String? fname = prefs.getString('fname');
    String? mname = prefs.getString('mname');
    String? lname = prefs.getString('lname');
    String? suffix = prefs.getString('suffix');
    String? appRole = prefs.getString(AppMobileRole.prefsKey);
    return {
      'id': id,
      'email': email,
      'token': token,
      'name': name,
      'phone': phone,
      'address': address,
      'account_status': accountStatus,
      'fname': fname,
      'mname': mname,
      'lname': lname,
      'suffix': suffix,
      AppMobileRole.prefsKey: appRole,
    };
  }

  Future<void> clearCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('id');
    await prefs.remove('email');
    await prefs.remove('token');
    await prefs.remove('name');
    await prefs.remove('phone');
    await prefs.remove('address');
    await prefs.remove('account_status');
    await prefs.remove('fname');
    await prefs.remove('mname');
    await prefs.remove('lname');
    await prefs.remove('suffix');
    await prefs.remove(AppMobileRole.prefsKey);
    await prefs.remove(AccountSession.prefsKeyVerificationDocsSubmitted);
  }
}
