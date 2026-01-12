// Helper function to decode JWT and extract claims
import 'dart:convert';

Map<String, dynamic> decodeJwt(String token) {
  // JWT has 3 parts separated by dots: header.payload.signature
  final parts = token.split('.');
  if (parts.length != 3) {
    throw Exception('Invalid JWT token');
  }

  // Decode the payload (middle part)
  final payload = parts[1];

  // JWT uses base64Url encoding, we need to normalize it
  var normalized = base64Url.normalize(payload);
  var decoded = utf8.decode(base64Url.decode(normalized));

  return json.decode(decoded) as Map<String, dynamic>;
}
