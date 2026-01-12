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

class AutoUpdateService extends ChangeNotifier {
  final String _currentVersion;
  Timer? _updateTimer;
  final Future<void> Function(String url, String dest) _downloader;
  final String _assetName;
  final String _repository;
  final SharedPreferences _pref;
  final Logger? logger;
  final Function() _exitCurrentApp;
  final String _cacheDir;

  // Auto-update checks are performed daily (every 24 hours) when enabled
  AutoUpdateService({
    required SharedPreferences pref,
    required String currentVersion,
    required Future<void> Function(String url, String dest) downloader,
    required String assetName,
    required String repository,
    required Future<void> Function() exitCurrentApp,
    required String cacheDir,
    this.logger,
  }) : _pref = pref,
       _currentVersion = currentVersion,
       _downloader = downloader,
       _assetName = assetName,
       _repository = repository,
       _exitCurrentApp = exitCurrentApp,
       _cacheDir = cacheDir {
    _initialize();
  }

  DownloadedInstaller? get downloadedInstaller {
    final json = _pref.getString('downloadedInstaller');
    if (json == null) return null;
    return DownloadedInstaller.fromJson(jsonDecode(json));
  }

  void setDownloadedInstallerPath(DownloadedInstaller? installer) {
    if (installer == null) {
      _pref.remove('downloadedInstaller');
    } else {
      _pref.setString('downloadedInstaller', jsonEncode(installer.toJson()));
    }
  }

  int? get lastUpdateCheckTime {
    return _pref.getInt('lastUpdateCheckTime');
  }

  void setLastUpdateCheckTime(int timestamp) {
    _pref.setInt('lastUpdateCheckTime', timestamp);
  }

  String? get skipVersion {
    return _pref.getString('skipVersion');
  }

  void setSkipVersion(String version) async {
    _pref.setString('skipVersion', version);
    await _deleteLocalApk();
  }

  String? downloadingVersion;
  // version and apk file path
  DownloadedInstaller? get hasLocalInstallerToInstall {
    final installer = downloadedInstaller;
    if (installer == null) {
      return null;
    }
    final localApkVersion = installer.version;
    if (localApkVersion == _currentVersion ||
        !versionNewerThan(localApkVersion, _currentVersion)) {
      _deleteLocalApk();
      return null;
    }
    return installer;
  }

  /// Check if enough time has passed since the last update check
  bool _shouldCheckAndUpdate() {
    if (downloadedInstaller != null) {
      return true;
    }

    final lastCheckTime = lastUpdateCheckTime;
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
    final lastCheckTime = lastUpdateCheckTime;
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
      startAutoUpdate();
    }
  }

  bool get autoUpdate => _pref.getBool('autoUpdate') ?? true;
  void setAutoUpdate(bool value) {
    _pref.setBool('autoUpdate', value);
    notifyListeners();
    updateAutoUpdateState();
  }

  /// Update auto-update state based on current preferences
  void updateAutoUpdateState() {
    if (autoUpdate) {
      startAutoUpdate();
    } else {
      stopAutoUpdate();
    }
  }

  /// Start automatic update checking
  void startAutoUpdate() {
    if (_updateTimer != null) return;

    logger?.i('Starting auto-update service');

    // Check if we need to check for updates based on last check time
    if (_shouldCheckAndUpdate()) {
      checkAndUpdate();
    } else {
      final timeUntilNextCheck = _getTimeUntilNextCheck();
      logger?.i(
        'Last check was recent, next check in: ${timeUntilNextCheck.inHours}h ${timeUntilNextCheck.inMinutes % 60}m',
      );
    }

    // Schedule daily checks (24 hours)
    const dailyInterval = Duration(hours: 24);
    _updateTimer = Timer.periodic(dailyInterval, (_) => checkAndUpdate());

    logger?.i('Auto-update service scheduled to check daily');
  }

  /// Stop automatic update checking
  void stopAutoUpdate() {
    logger?.i('Stopping auto-update service');
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  Future<GitHubRelease?> checkForUpdates(String currentVersion) async {
    try {
      final release = await getLatestReleaseContainingNewerAndroidApk(
        _repository,
        currentVersion,
        _assetName,
      );
      if (release == null) {
        return null;
      }
      return release;
    } catch (e, stackTrace) {
      logger?.e('Error checking for updates', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Check for updates and install if there is a new version
  Future<void> checkAndUpdate() async {
    logger?.i('checkAndUpdate');

    try {
      // _prefHelper.setDownloadedApkPath(join(await getCacheDir(), '2.0.12.apk'));
      // check if there is a previously downloaded apk
      final localInstaller = downloadedInstaller;
      // get newest version
      final release = await checkForUpdates(_currentVersion);
      if (release != null) {
        final newestVersion = release.version;
        // if local apk exist
        if (localInstaller != null) {
          final localVersion = localInstaller.version;
          // if it is older than the newest version, delete it
          if (localVersion != newestVersion) {
            logger?.d('local apk not newest, delete it $localInstaller');
            await _deleteLocalApk();
          } else {
            if (skipVersion == newestVersion) {
              logger?.d('skip this version, delete local apk $localInstaller');
              await _deleteLocalApk();
            } else {
              logger?.d('local apk is newest, notify listeners');
              notifyListeners();
            }
            return;
          }
          // no local apk, download it
        }
        if (skipVersion == newestVersion) {
          logger?.d('skip this version, no need to download');
          return;
        }

        downloadingVersion = newestVersion;
        notifyListeners();

        await _downloadToLocal(release).catchError((error) {
          logger?.e('Error downloading update', error: error);
        });

        downloadingVersion = null;
        notifyListeners();
      }
      setLastUpdateCheckTime(DateTime.now().millisecondsSinceEpoch);
    } catch (e, stackTrace) {
      logger?.e('_checkAndUpdate', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _downloadToLocal(GitHubRelease release) async {
    final newestDownloadUrl = 'https://download.5vnetwork.com/$_assetName';

    if (Platform.isAndroid) {
      final zipPath = join(_cacheDir, '${release.version}.apk.zip');
      logger?.d('downloading new apk zip $zipPath');
      await _downloader(newestDownloadUrl, zipPath).then((
        value,
      ) async {
        logger?.d('downloaded new apk zip $zipPath, extract it');
        final apkFolder = zipPath.replaceAll(".apk.zip", "");
        // a folder named ${version} will be created and inside it there is a vx-arm64-v8a.apk
        await extractFileToDisk(zipPath, apkFolder);
        File(zipPath).deleteSync();
        // move the apk out of the folder and delete the folder
        final apkFile = File(join(apkFolder, "vx-arm64-v8a.apk"));
        final newApkFile = apkFile.renameSync(
          join(_cacheDir, "${release.version}.apk"),
        );
        Directory(apkFolder).deleteSync(recursive: true);

        setDownloadedInstallerPath(
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
      setDownloadedInstallerPath(
        DownloadedInstaller(
          version: release.version,
          path: downloadDest,
          newFeatures: release.body,
        ),
      );
    } else if (Platform.isLinux) {
      logger?.d('Downloading installer for Linux $newestDownloadUrl');
      final downloadDest = join(_cacheDir, '${release.version}_$_assetName');
      await _downloader(newestDownloadUrl, downloadDest);
      setDownloadedInstallerPath(
        DownloadedInstaller(
          version: release.version,
          path: downloadDest,
          newFeatures: release.body,
        ),
      );
    }
  }

  _deleteLocalApk() {
    final localInstaller = downloadedInstaller;
    if (localInstaller != null) {
      final apkFile = File(localInstaller.path);
      if (apkFile.existsSync()) {
        apkFile.deleteSync();
      }
      setDownloadedInstallerPath(null);
      notifyListeners();
    }
  }

  Future<void> installLocalInstaller() async {
    final installer = downloadedInstaller;
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
            await _deleteLocalApk();
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
    stopAutoUpdate();
    super.dispose();
  }

  void Function() getListener(GlobalKey<NavigatorState> rootNavigationKey) {
    return () {
      if (rootNavigationKey.currentContext == null) {
        return;
      }

      final localInstaller = hasLocalInstallerToInstall;
      if (localInstaller != null) {
        final version = localInstaller.version;
        showDialog(
          context: rootNavigationKey.currentContext!,
          builder: (context) => AlertDialog(
            title: Text(
              AppLocalizations.of(context)!.newVersionDownloadedDialog(version),
            ),
            content: Text(localInstaller.newFeatures),
            actions: [
              OutlinedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  setSkipVersion(version);
                },
                child: Text(AppLocalizations.of(context)!.skipThisVersion),
              ),
              FilledButton.tonal(
                onPressed: () async {
                  Navigator.of(context).pop();
                  try {
                    await installLocalInstaller();
                  } catch (e) {
                    if (rootNavigationKey.currentContext!.mounted) {
                      showAlertDialog(
                        rootNavigationKey.currentContext!,
                        AppLocalizations.of(
                          context,
                        )!.installFailed(e.toString()),
                      );
                    }
                  }
                },
                child: Text(AppLocalizations.of(context)!.install),
              ),
            ],
          ),
        );
      }
    };
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
