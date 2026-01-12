import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_common/util/version.dart';

class GitHubRelease {
  final String tagName;
  final String name;
  final String body;
  final bool prerelease;
  final bool draft;
  final DateTime publishedAt;
  final List<GitHubAsset> assets;

  GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.prerelease,
    required this.draft,
    required this.publishedAt,
    required this.assets,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    return GitHubRelease(
      tagName: json['tag_name'] ?? '',
      name: json['name'] ?? '',
      body: json['body'] ?? '',
      prerelease: json['prerelease'] ?? false,
      draft: json['draft'] ?? false,
      publishedAt: DateTime.parse(
        json['published_at'] ?? DateTime.now().toIso8601String(),
      ),
      assets:
          (json['assets'] as List<dynamic>?)
              ?.map((asset) => GitHubAsset.fromJson(asset))
              .toList() ??
          [],
    );
  }

  String getDownloadUrl(String assetName) =>
      assets.firstWhere((e) => e.name == assetName).downloadUrl;

  String get version => tagName.replaceAll('v', '');
}

class GitHubAsset {
  final String name;
  final String downloadUrl;
  final int size;
  final String contentType;
  final DateTime updatedAt;

  GitHubAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
    required this.contentType,
    required this.updatedAt,
  });

  factory GitHubAsset.fromJson(Map<String, dynamic> json) {
    return GitHubAsset(
      name: json['name'] ?? '',
      downloadUrl: json['browser_download_url'] ?? '',
      size: json['size'] ?? 0,
      contentType: json['content_type'] ?? '',
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  factory GitHubAsset.empty() {
    return GitHubAsset(
      name: '',
      downloadUrl: '',
      size: 0,
      contentType: '',
      updatedAt: DateTime.now(),
    );
  }

  bool get isEmpty => name.isEmpty;
}

const githubApiUrl = 'https://api.github.com';

/// Fetch the latest release from GitHub
Future<GitHubRelease?> getLatestReleaseContainingNewerAndroidApk(
  String repository,
  String currentVersion,
  String assetName,
) async {
  final url = '$githubApiUrl/repos/$repository/releases';
  final response = await http
      .get(
        Uri.parse(url),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      )
      .timeout(const Duration(seconds: 10));

  if (response.statusCode == 200) {
    final json = jsonDecode(response.body) as List<dynamic>;
    final releases = json
        .map((e) => GitHubRelease.fromJson(e))
        .where((r) => !r.prerelease)
        .toList();
    for (var release in releases) {
      if (versionNewerThan(release.version, currentVersion)) {
        if (release.assets.any((e) => e.name == assetName)) {
          return release;
        }
      }
    }
    return null;
  } else {
    throw Exception(
      'Failed to fetch latest release. Status: ${response.statusCode}',
    );
  }
}
