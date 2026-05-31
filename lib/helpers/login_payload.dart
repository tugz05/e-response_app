/// Normalizes Laravel login JSON so we always read `id`, `token`, `app_role`,
/// etc. from the same [Map], whether the API uses a flat `data` object or
/// nests the user under `data.user` (common with Sanctum / API resources).
class LoginPayload {
  LoginPayload._();

  /// Full decoded login JSON (must contain top-level `data`).
  static Map<String, dynamic> userMapFromLoginBody(Map<String, dynamic> apiBody) {
    final root = apiBody['data'];
    if (root is! Map) {
      throw const FormatException('Login response missing data object');
    }
    return mergeNestedUser(Map<String, dynamic>.from(root));
  }

  /// Laravel's inner `data` object only (already unwrapped from the HTTP root).
  static Map<String, dynamic> userMapFromDataObject(Map<String, dynamic> data) {
    return mergeNestedUser(Map<String, dynamic>.from(data));
  }

  static Map<String, dynamic> mergeNestedUser(Map<String, dynamic> data) {
    final nestedUser = data['user'];
    if (nestedUser is Map) {
      final u = Map<String, dynamic>.from(nestedUser);
      for (final e in data.entries) {
        if (e.key == 'user') {
          continue;
        }
        if (e.value != null) {
          u.putIfAbsent(e.key, () => e.value);
        }
      }
      return u;
    }
    return data;
  }
}
