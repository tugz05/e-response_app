import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/account_session.dart';
import '../helpers/api_url.dart';

class ImageUploadService {
  /// Uploads ID + selfie. On HTTP 200, marks account as **pending admin review**
  /// so routing shows [VerifyAccountScreen] instead of document upload again.
  ///
  /// Copies images into app documents so profile avatars still work after temp
  /// cache paths from the picker are cleared.
  Future<bool> uploadImages(String id, File idImage, File selfieImage) async {
    try {
      final String apiUrl = ApiUrl.getServiceUrl('api/v1/valid-images/$id');
      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      request.files.add(
        await http.MultipartFile.fromPath('img_valid_id', idImage.path),
      );
      request.files.add(
        await http.MultipartFile.fromPath('img_selfie', selfieImage.path),
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'multipart/form-data',
      });

      final response = await request.send();

      if (response.statusCode == 200) {
        await _persistVerificationImagesLocal(idImage, selfieImage);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          AccountSession.prefsKeyVerificationDocsSubmitted,
          true,
        );
        await prefs.setString(
          AccountSession.prefsKeyAccountStatus,
          'pending_verification',
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistVerificationImagesLocal(
    File idImage,
    File selfieImage,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final idDest = File('${dir.path}/verification_id.jpg');
    final selfieDest = File('${dir.path}/verification_selfie.jpg');
    await idImage.copy(idDest.path);
    await selfieImage.copy(selfieDest.path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('img_valid_id', idDest.path);
    await prefs.setString('img_selfie', selfieDest.path);
  }

  Future<Map<String, String?>> getSavedImages() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'img_valid_id': prefs.getString('img_valid_id'),
      'img_selfie': prefs.getString('img_selfie'),
    };
  }
}
