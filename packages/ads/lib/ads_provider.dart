// Copyright (C) 2026 5V Network LLC <5vnetwork@proton.me>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_common/common.dart';
import 'package:flutter_common/services/periodic.dart';
import 'package:flutter_common/types/downloader.dart';
import 'package:flutter_common/types/logger.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

typedef DownloadFunction = Future<void> Function(String url, String dest);

class AdsProvider with ChangeNotifier {
  AdsProvider({
    required String adsDirectory,
    required SharedPreferences sharedPreferences,
    required DownloadFunction downloadFunction,
    Logger? logger,
    Duration refreshInterval = const Duration(hours: 24),
  }) : _adsDirectory = adsDirectory,
       _sharedPreferences = sharedPreferences,
       _downloadFunction = downloadFunction,
       _logger = logger,
       _refreshInterval = refreshInterval {
    periodicTask = PeriodicTask(
      sharedPreferences: sharedPreferences,
      task: _fetchAds,
      lastRunKey: 'lastAdsFetchTime',
      period: refreshInterval,
    );
  }

  final Logger? _logger;
  late final PeriodicTask periodicTask;

  void start() {
    _logger?.d('Starting ads provider');
    _loadAds();
    periodicTask.start();
  }

  void stop() {
    _logger?.d('Stopping ads provider');
    _timer?.cancel();
    _timer = null;
    _adsToShow.clear();
    _adsShown.clear();
    periodicTask.stop();
  }

  // LinkedList for ads to be shown
  final Queue<Ad> _adsToShow = Queue<Ad>();
  // LinkedList for ads that have been shown
  final Queue<Ad> _adsShown = Queue<Ad>();
  Timer? _timer;
  int get adsLen => _adsToShow.length + _adsShown.length;
  // Remote URL to fetch ads configuration from
  // The URL should return a JSON array of ad objects with 'name', 'website', and 'imageUrl'
  String? remoteUrl;
  // This directory will contain a metadata file and a list of ads
  final String _adsDirectory;
  static const String _adsMetadataFile = 'ads.json';
  final SharedPreferences _sharedPreferences;
  final DownloadFunction _downloadFunction;
  final Duration _refreshInterval;

  bool userInChina(SharedPreferences persistentStateRepo) {
    return PlatformDispatcher.instance.locale.countryCode == 'CN' ||
        PlatformDispatcher.instance.locale.languageCode == 'zh';
  }

  /// Move to next ad that fits within constraints
  Ad? getNextAd({double? maxHeight, double? maxWidth}) {
    if (applePlatform && !userInChina(_sharedPreferences)) {
      return null;
    }
    // If no ads to show, swap the queues
    if (_adsToShow.isEmpty) {
      if (_adsShown.isEmpty) return null; // No ads at all
      // Swap the two queues
      _adsToShow.addAll(_adsShown);
      _adsShown.clear();
      // Shuffle the ads for variety
      // final adsList = _adsToShow.toList()..shuffle(Random());
      // _adsToShow.clear();
      // _adsToShow.addAll(adsList);
      // _logger?.i('Swapped ad queues, reset with ${_adsToShow.length} ads');
    }

    // Iterate through ads to find one that meets constraints
    Ad? selectedAd = _getSuitableAd(
      ads: _adsToShow,
      maxHeight: maxHeight,
      maxWidth: maxWidth,
    );
    // pick one from _adsShown if no suitable ad found in _adsToShow
    if (selectedAd == null && _adsShown.isNotEmpty) {
      selectedAd = _getSuitableAdFromRandomStart(
        ads: _adsShown,
        maxHeight: maxHeight,
        maxWidth: maxWidth,
      );
      if (selectedAd == null) {
        return null;
      }
      selectedAd.imageProvider ??= FileImage(
        File(path.join(_adsDirectory, selectedAd.name)),
      );
      // _logger?.d('Showing ad: ${selectedAd.name}');
      return selectedAd;
    }

    if (selectedAd == null) {
      return null;
    }
    // If we found a suitable ad, remove it from _adsToShow and add to _adsShown
    selectedAd.imageProvider ??= FileImage(
      File(path.join(_adsDirectory, selectedAd.name)),
    );
    _adsToShow.remove(selectedAd);
    _adsShown.add(selectedAd);
    // _logger?.i('Showing ad: ${selectedAd.name}');
    return selectedAd;
  }

  Ad? _getSuitableAd({
    required Queue<Ad> ads,
    double? maxHeight,
    double? maxWidth,
  }) {
    // Iterate through ads to find one that meets constraints
    Ad? selectedAd;
    final iterator = ads.iterator;
    while (iterator.moveNext()) {
      final ad = iterator.current;
      final preferredSize = ad.fittedSize();
      if (maxHeight != null && preferredSize.height > maxHeight) {
        continue;
      }
      if (maxWidth != null && preferredSize.width > maxWidth) {
        continue;
      }
      selectedAd = ad;
      break;
    }
    // if no ad meets constraints, try to find one that meets constraints * 1.5
    if (selectedAd == null) {
      final relaxedIterator = ads.iterator;
      while (relaxedIterator.moveNext()) {
        final ad = relaxedIterator.current;
        final preferredSize = ad.fittedSize();
        if (maxHeight != null && preferredSize.height > maxHeight * 1.5) {
          continue;
        }
        if (maxWidth != null && preferredSize.width > maxWidth * 1.5) {
          continue;
        }
        selectedAd = ad;
        break;
      }
    }
    return selectedAd;
  }

  Ad? _getSuitableAdFromRandomStart({
    required Queue<Ad> ads,
    double? maxHeight,
    double? maxWidth,
  }) {
    if (ads.isEmpty) return null;
    final start = Random().nextInt(ads.length);

    int index = 0;
    var iterator = ads.iterator;
    final relaxedMaxHeight = maxHeight != null ? maxHeight * 1.5 : null;
    final relaxedMaxWidth = maxWidth != null ? maxWidth * 1.5 : null;
    // Relaxed pass: [start, end)
    while (iterator.moveNext()) {
      if (index < start) {
        index++;
        continue;
      }
      final ad = iterator.current;
      final preferredSize = ad.fittedSize();
      if (relaxedMaxHeight != null && preferredSize.height > relaxedMaxHeight) {
        index++;
        continue;
      }
      if (relaxedMaxWidth != null && preferredSize.width > relaxedMaxWidth) {
        index++;
        continue;
      }
      return ad;
    }

    index = 0;
    iterator = ads.iterator;
    // Relaxed pass: [0, start)
    while (iterator.moveNext()) {
      if (index >= start) {
        break;
      }
      final ad = iterator.current;
      final preferredSize = ad.fittedSize();
      if (relaxedMaxHeight != null && preferredSize.height > relaxedMaxHeight) {
        index++;
        continue;
      }
      if (relaxedMaxWidth != null && preferredSize.width > relaxedMaxWidth) {
        index++;
        continue;
      }
      return ad;
    }

    return null;
  }

  void _setLastAdsFetchTime(DateTime time) {
    _sharedPreferences.setInt('lastAdsFetchTime', time.millisecondsSinceEpoch);
  }

  /// Load local ads
  void _loadAds() async {
    List<Ad> loadedAds = [];
    try {
      final metadataFile = File(path.join(_adsDirectory, _adsMetadataFile));
      if (metadataFile.existsSync()) {
        final List<dynamic> adsJson = jsonDecode(
          metadataFile.readAsStringSync(),
        );
        // Parse ads and filter out expired ones
        loadedAds = adsJson
            .map((json) => Ad.fromJson(json))
            .where((ad) => ad.expiresAt.isAfter(DateTime.now()))
            .toList();
      }

      // in addition, load build-in ads from assets
      try {
        final List<dynamic> bundledAdJson = jsonDecode(
          await rootBundle.loadString('packages/ads/assets/ads/ads.json'),
        );
        loadedAds.addAll(
          bundledAdJson.map((json) {
            final ad = Ad.fromJson(json);
            ad.imageProvider = AssetImage('packages/ads/assets/ads/${ad.name}');
            return ad;
          }).toList(),
        );
      } catch (e) {
        _logger?.d('Error loading bundled ads', error: e);
      }

      // Shuffle and add to _adsToShow queue
      loadedAds.shuffle(Random());
      _adsToShow.clear();
      _adsShown.clear();
      _adsToShow.addAll(loadedAds);
      notifyListeners();
      _logger?.i('Loaded ${_adsToShow.length} cached ads');
    } catch (e) {
      _logger?.e('Error loading cached ads: $e');
    }
  }

  /// Check if we need to fetch ads today
  static const _adsZipUrl = 'https://ads.5vnetwork.com/ads.zip';

  Future<void> _downloadZip() async {
    final dest = path.join(_adsDirectory, 'ads.zip');
    try {
      await _downloadFunction(_adsZipUrl, dest);
      // delete all files in _adsDirectory expect ads.zip
      // for (final file in Directory(_adsDirectory).listSync()) {
      //   if (file.path != dest) {
      //     file.deleteSync();
      //   }
      // }
      // unzip the file to dest. If dest already exists, there will be no error.
      // existing files that are also in the zip will be replaced
      // if dest does not exist, it will be created
      await extractFileToDisk(dest, _adsDirectory);
    } catch (e) {
      _logger?.e('Error downloading ads zip: $e');
    } finally {
      File(dest).deleteSync();
    }
  }

  /// Fetch ads.zip from remote URL and extract it to _adsDirectory
  Future<void> _fetchAds() async {
    try {
      await _downloadZip();
      _loadAds();
    } catch (e) {
      _logger?.e('Error fetching ads: $e');
    }
  }

  Future<List<Ad>> fetchAllAds() async {
    await _downloadZip();
    _setLastAdsFetchTime(DateTime.now());
    final metadataFile = File(path.join(_adsDirectory, _adsMetadataFile));
    if (!metadataFile.existsSync()) {
      return [];
    }
    final List<dynamic> adsJson = jsonDecode(metadataFile.readAsStringSync());
    // Parse ads and filter out expired ones
    final loadedAds = adsJson
        .map((json) => Ad.fromJson(json))
        .where((ad) => ad.expiresAt.isAfter(DateTime.now()))
        .toList();
    for (final ad in loadedAds) {
      ad.imageProvider = FileImage(File(path.join(_adsDirectory, ad.name)));
    }
    return loadedAds;
  }
}

enum AdImageType { png, jpg, jpeg, gif, webp }

enum AdCategory { airportVpn, vps, others }

class Ad {
  final String name;
  final String website;
  final DateTime expiresAt;
  final int width;
  final int height;
  final int? assetWidthPx;
  final int? assetHeightPx;
  final String? adSizePreset;
  final AdImageType imageType;
  ImageProvider? imageProvider;

  Ad({
    required this.name,
    required this.website,
    required this.expiresAt,
    required this.width,
    required this.height,
    this.assetWidthPx,
    this.assetHeightPx,
    this.adSizePreset,
    required this.imageType,
  });

  double get imageAspectRatio {
    final sourceWidth = assetWidthPx ?? width;
    final sourceHeight = assetHeightPx ?? height;
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return 1;
    }
    return sourceWidth / sourceHeight;
  }

  /// Return the layout size of the ad. (The size that will be used to display the ad)
  Size fittedSize({double? maxWidth, double? maxHeight}) {
    var fittedWidth = width.toDouble();
    var fittedHeight = height.toDouble();
    final aspectRatio = imageAspectRatio;

    // Maintain the aspect ratio of the image, fit it within the original desired container,
    // such as 320x50, 320x100, 468x60, 728x90, etc.
    if (fittedWidth > 0 && fittedHeight > 0) {
      final preferredHeight = fittedWidth / aspectRatio;
      if (preferredHeight <= fittedHeight) {
        fittedHeight = preferredHeight;
      } else {
        fittedWidth = fittedHeight * aspectRatio;
      }
    }

    // Fit the desired container to the constraints
    if (maxWidth != null && fittedWidth > maxWidth) {
      final scale = maxWidth / fittedWidth;
      fittedWidth *= scale;
      fittedHeight *= scale;
    }
    if (maxHeight != null && fittedHeight > maxHeight) {
      final scale = maxHeight / fittedHeight;
      fittedWidth *= scale;
      fittedHeight *= scale;
    }

    return Size(fittedWidth, fittedHeight);
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'website': website,
    'expiresAt': expiresAt.toIso8601String(),
    'width': width,
    'height': height,
    if (assetWidthPx != null) 'assetWidthPx': assetWidthPx,
    if (assetHeightPx != null) 'assetHeightPx': assetHeightPx,
    if (adSizePreset != null) 'adSizePreset': adSizePreset,
    'imageType': imageType.name,
  };

  factory Ad.fromJson(Map<String, dynamic> json) => Ad(
    name: json['name'],
    website: json['website'],
    expiresAt: DateTime.parse(json['expiresAt']),
    width: json['width'],
    height: json['height'],
    assetWidthPx: json['assetWidthPx'],
    assetHeightPx: json['assetHeightPx'],
    adSizePreset: json['adSizePreset'],
    imageType: AdImageType.values.byName(json['imageType']),
  );
}
