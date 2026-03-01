import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:android_package_installer/android_package_installer.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_common/common.dart';
import 'package:flutter_common/l10n/app_localizations.dart';
import 'package:flutter_common/util/github.dart';
import 'package:flutter_common/util/linux.dart';
import 'package:flutter_common/util/version.dart';
import 'package:flutter_common/widgets/dialog.dart';

/// When enabled, listeners will be notified when there is a DownloadedInstaller
class AutoUpdateService extends ChangeNotifier {
  final String _currentVersion;
  Timer? _updateTimer;
  final Future<void> Function(String url, String dest) _downloader;
  final String _assetName;
  final String _repository;
  final SharedPreferences _pref;
  final Logger? _logger;
  final Function() _exitCurrentApp;
  final String _cacheDir;
  final String _downloadUrl;

  // Auto-update checks are performed daily (every 24 hours) when enabled
  AutoUpdateService({
    required SharedPreferences pref,
    required String currentVersion,
    required Future<void> Function(String url, String dest) downloader,
    required String assetName,
    required String repository,
    required Future<void> Function() exitCurrentApp,
    required String cacheDir,
    required String downloadUrl,
    Logger? logger,
  }) : _logger = logger,
       _pref = pref,
       _currentVersion = currentVersion,
       _downloader = downloader,
       _assetName = assetName,
       _repository = repository,
       _exitCurrentApp = exitCurrentApp,
       _cacheDir = cacheDir,
       _downloadUrl = downloadUrl {
    _initialize();
  }

  void _setDownloadedInstallerPath(DownloadedInstaller? installer) {
    if (installer == null) {
      _pref.remove('downloadedInstaller');
    } else {
      _pref.setString('downloadedInstaller', jsonEncode(installer.toJson()));
    }
  }

  int? get _lastUpdateCheckTime {
    return _pref.getInt('lastUpdateCheckTime');
  }

  void _setLastUpdateCheckTime(int timestamp) {
    _pref.setInt('lastUpdateCheckTime', timestamp);
  }

  String? get _skipVersion {
    return _pref.getString('skipVersion');
  }

  void setSkipCurrentInstaller() async {
    final localInstaller = this.localInstaller;
    if (localInstaller == null) {
      return;
    }
    _pref.setString('skipVersion', localInstaller.version);
    await _deleteLocalInstaller();
  }

  String? downloadingVersion;
  // version and apk file path
  DownloadedInstaller? get localInstaller {
    final json = _pref.getString('downloadedInstaller');
    if (json == null) return null;
    final installer = DownloadedInstaller.fromJson(jsonDecode(json));
    final localApkVersion = installer.version;
    if (localApkVersion == _currentVersion ||
        !versionNewerThan(localApkVersion, _currentVersion)) {
      _deleteLocalInstaller();
      return null;
    }
    return installer;
  }

  /// Check if enough time has passed since the last update check
  bool _shouldCheckAndUpdate() {
    if (localInstaller != null) {
      return true;
    }

    final lastCheckTime = _lastUpdateCheckTime;
    if (lastCheckTime == null) {
      // First time running, should check
      return true;
    }

    final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckTime);
    final now = DateTime.now();
    final timeSinceLastCheck = now.difference(lastCheck);

    // Check if 24 hours have passed
    return timeSinceLastCheck.inHours >= 24;
  }

  /// Get the time remaining until the next update check
  Duration _getTimeUntilNextCheck() {
    final lastCheckTime = _lastUpdateCheckTime;
    if (lastCheckTime == null) {
      return Duration.zero;
    }

    final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckTime);
    final now = DateTime.now();
    final nextCheck = lastCheck.add(const Duration(hours: 24));

    return nextCheck.difference(now);
  }

  void _initialize() {
    // Start auto-update if enabled
    if (autoUpdate) {
      _startAutoUpdate();
    }
  }

  bool get autoUpdate => _pref.getBool('autoUpdate') ?? true;
  void setAutoUpdate(bool value) {
    _pref.setBool('autoUpdate', value);
    notifyListeners();
    _updateAutoUpdateState();
  }

  /// Update auto-update state based on current preferences
  void _updateAutoUpdateState() {
    if (autoUpdate) {
      _startAutoUpdate();
    } else {
      _stopAutoUpdate();
    }
  }

  /// Start automatic update checking
  void _startAutoUpdate() {
    if (_updateTimer != null) return;

    _logger?.i('Starting auto-update service');

    // Check if we need to check for updates based on last check time
    if (_shouldCheckAndUpdate()) {
      checkAndUpdate();
    } else {
      final timeUntilNextCheck = _getTimeUntilNextCheck();
      _logger?.i(
        'Last check was recent, next check in: ${timeUntilNextCheck.inHours}h ${timeUntilNextCheck.inMinutes % 60}m',
      );
    }

    // Schedule daily checks (24 hours)
    const dailyInterval = Duration(hours: 24);
    _updateTimer = Timer.periodic(dailyInterval, (_) => checkAndUpdate());

    _logger?.i('Auto-update service scheduled to check daily');
  }

  /// Stop automatic update checking
  void _stopAutoUpdate() {
    _logger?.i('Stopping auto-update service');
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Returns the latest release if there is a new version
  Future<GitHubRelease?> checkForUpdates() async {
    if (kDebugMode) {
      return GitHubRelease(
        tagName: '9.9.9',
        name: '9.9.9',
        prerelease: false,
        draft: false,
        body: 'Test',
        assets: [
          GitHubAsset(
            name: '9.9.9.apk',
            downloadUrl: '',
            size: 1000,
            contentType: 'application/vnd.android.package-archive',
            updatedAt: DateTime.now(),
          ),
        ],
        publishedAt: DateTime.now(),
      );
    }
    try {
      final release = await getLatestReleaseContainingNewerAndroidApk(
        _repository,
        _currentVersion,
        _assetName,
      );
      if (release == null) {
        return null;
      }
      return release;
    } catch (e, stackTrace) {
      _logger?.e(
        'Error checking for updates',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Check for updates and install if there is a new version
  Future<void> checkAndUpdate() async {
    _logger?.i('checkAndUpdate');

    try {
      // _prefHelper.setDownloadedApkPath(join(await getCacheDir(), '2.0.12.apk'));
      // check if there is a previously downloaded apk
      // get newest version
      final release = await checkForUpdates();
      if (release != null) {
        final newestVersion = release.version;
        // if local apk exist
        final localInstaller = this.localInstaller;
        if (localInstaller != null) {
          final localVersion = localInstaller.version;
          // if it is older than the newest version, delete it
          if (localVersion != newestVersion) {
            _logger?.d('local apk not newest, delete it $localInstaller');
            await _deleteLocalInstaller();
          } else {
            if (_skipVersion == newestVersion) {
              _logger?.d('skip this version, delete local apk $localInstaller');
              await _deleteLocalInstaller();
            } else {
              _logger?.d('local apk is newest, notify listeners');
              notifyListeners();
            }
            return;
          }
          // no local apk, download it
        }
        if (_skipVersion == newestVersion) {
          _logger?.d('skip this version, no need to download');
          return;
        }

        downloadingVersion = newestVersion;
        notifyListeners();

        await _downloadToLocal(release).catchError((error) {
          _logger?.e('Error downloading update', error: error);
        });

        downloadingVersion = null;
        notifyListeners();
      }
      _setLastUpdateCheckTime(DateTime.now().millisecondsSinceEpoch);
    } catch (e, stackTrace) {
      _logger?.e('_checkAndUpdate', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _downloadToLocal(GitHubRelease release) async {
    final newestDownloadUrl = '$_downloadUrl/$_assetName';

    if (Platform.isAndroid) {
      final zipPath = join(_cacheDir, '${release.version}.apk.zip');
      _logger?.d('downloading new apk zip $zipPath');
      await _downloader(newestDownloadUrl, zipPath).then((value) async {
        _logger?.d('downloaded new apk zip $zipPath, extract it');
        final apkFolder = zipPath.replaceAll(".apk.zip", "");
        // a folder named ${version} will be created and inside it there is a vx-arm64-v8a.apk
        await extractFileToDisk(zipPath, apkFolder);
        File(zipPath).deleteSync();
        // move the apk out of the folder and delete the folder
        final apkFile = File(
          join(apkFolder, _assetName.replaceAll(".zip", "")),
        );
        final newApkFile = apkFile.renameSync(
          join(_cacheDir, "${release.version}.apk"),
        );
        Directory(apkFolder).deleteSync(recursive: true);

        _setDownloadedInstallerPath(
          DownloadedInstaller(
            version: release.version,
            path: newApkFile.path,
            newFeatures: release.body,
          ),
        );
      });
    } else if (Platform.isWindows) {
      final downloadDest = join(_cacheDir, '${release.version}_$_assetName');
      await _downloader(newestDownloadUrl, downloadDest);
      _setDownloadedInstallerPath(
        DownloadedInstaller(
          version: release.version,
          path: downloadDest,
          newFeatures: release.body,
        ),
      );
    } else if (Platform.isLinux) {
      _logger?.d('Downloading installer for Linux $newestDownloadUrl');
      final downloadDest = join(_cacheDir, '${release.version}_$_assetName');
      await _downloader(newestDownloadUrl, downloadDest);
      _setDownloadedInstallerPath(
        DownloadedInstaller(
          version: release.version,
          path: downloadDest,
          newFeatures: release.body,
        ),
      );
    }
  }

  Future<void> _deleteLocalInstaller() async {
    final localInstaller = this.localInstaller;
    if (localInstaller != null) {
      final apkFile = File(localInstaller.path);
      if (apkFile.existsSync()) {
        apkFile.deleteSync();
      }
      _setDownloadedInstallerPath(null);
      notifyListeners();
    }
  }

  /// Install the downloaded installer
  Future<void> installLocalInstaller() async {
    final installer = localInstaller;
    if (installer == null) {
      throw Exception('No installer found');
    }
    if (Platform.isAndroid) {
      if (File(installer.path).existsSync()) {
        int? statusCode = await AndroidPackageInstaller.installApk(
          apkFilePath: installer.path,
        );
        if (statusCode != null) {
          PackageInstallerStatus installationStatus =
              PackageInstallerStatus.byCode(statusCode);
          if (installationStatus == PackageInstallerStatus.success) {
            await _deleteLocalInstaller();
          } else {
            throw Exception('Failed to install update: $statusCode');
          }
        }
      } else {
        throw Exception('Installer file not found');
      }
    } else if (Platform.isWindows) {
      await Process.start(
        // runInShell: true,
        // mode: ProcessStartMode.detached,
        'powershell.exe',
        ['-Command', 'Start-Process', installer.path],
      );
      await _exitCurrentApp();
    } else {
      await Process.run('gnome-terminal', [
        '--',
        'bash',
        '-c',
        'echo "Running the following command to update VX:"; echo "sudo ${isRpm() ? 'dnf install' : 'dpkg -i'} ${installer.path}"; bash',
      ]);
      // await exitCurrentApp();
    }
  }

  @override
  void dispose() {
    _stopAutoUpdate();
    super.dispose();
  }

  // void Function() getListener(GlobalKey<NavigatorState> rootNavigationKey) {
  //   return () {
  //     if (rootNavigationKey.currentContext == null) {
  //       return;
  //     }

  //     final localInstaller = hasLocalInstallerToInstall;
  //     if (localInstaller != null) {
  //       final version = localInstaller.version;
  //       showDialog(
  //         context: rootNavigationKey.currentContext!,
  //         builder: (context) => ,
  //       );
  //     }
  //   };
  // }
}

class InstallNewerVersionDialog extends StatelessWidget {
  const InstallNewerVersionDialog({
    super.key,
    required this.downloadedInstaller,
    required this.autoUpdateService,
  });
  final DownloadedInstaller downloadedInstaller;
  final AutoUpdateService autoUpdateService;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        AppLocalizations.of(
          context,
        )!.newVersionDownloadedDialog(downloadedInstaller.version),
      ),
      content: Text(downloadedInstaller.newFeatures),
      actions: [
        OutlinedButton(
          onPressed: () async {
            Navigator.of(context).pop();
            autoUpdateService.setSkipCurrentInstaller();
          },
          child: Text(AppLocalizations.of(context)!.skipThisVersion),
        ),
        FilledButton.tonal(
          onPressed: () async {
            Navigator.of(context).pop();
            try {
              await autoUpdateService.installLocalInstaller();
            } catch (e) {
              if (context.mounted) {
                showAlertDialog(
                  context,
                  AppLocalizations.of(context)!.installFailed(e.toString()),
                );
              }
            }
          },
          child: Text(AppLocalizations.of(context)!.install),
        ),
      ],
    );
  }
}

class DownloadedInstaller {
  final String version;
  final String path;
  final String newFeatures;

  DownloadedInstaller({
    required this.version,
    required this.path,
    required this.newFeatures,
  });

  factory DownloadedInstaller.fromJson(Map<String, dynamic> json) {
    return DownloadedInstaller(
      version: json['version'],
      path: json['path'],
      newFeatures: json['newFeatures'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'version': version, 'path': path, 'newFeatures': newFeatures};
  }
}
