import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/api_url.dart';

class ImageUploadService {

  

  Future<void> uploadImages(String id, File idImage, File selfieImage) async {
    try {
      String _apiUrl = ApiUrl.getServiceUrl("api/v1/valid-images/$id");
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      
      request.files.add(await http.MultipartFile.fromPath('img_valid_id', idImage.path));
      request.files.add(await http.MultipartFile.fromPath('img_selfie', selfieImage.path));
      
      request.headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'multipart/form-data'
      });
      
      var response = await request.send();
      
      if (response.statusCode == 200) {
        print("Upload successful");
        await _saveImagePaths(idImage.path, selfieImage.path);
      } else {
        print("Upload failed with status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error uploading images: $e");
    }
  }

  Future<void> _saveImagePaths(String idImagePath, String selfieImagePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('img_valid_id', idImagePath);
    await prefs.setString('img_selfie', selfieImagePath);
  }

  Future<Map<String, String?>> getSavedImages() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'img_valid_id': prefs.getString('img_valid_id'),
      'img_selfie': prefs.getString('img_selfie'),
    };
  }
}
