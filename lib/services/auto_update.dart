import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:android_package_installer/android_package_installer.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_common/services/periodic.dart';
import 'package:flutter_common/types/logger.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_common/common.dart';
import 'package:flutter_common/l10n/app_localizations.dart';
import 'package:flutter_common/util/github.dart';
import 'package:flutter_common/util/linux.dart';
import 'package:flutter_common/util/version.dart';
import 'package:flutter_common/widgets/dialog.dart';

/// When enabled, listeners will be notified when there is a DownloadedInstaller
class AutoUpdateService {
  final String _currentVersion;
  PeriodicTask? _timer;
  final Future<void> Function(String url, String dest) _downloader;
  final String _assetName;
  final String _repository;
  final SharedPreferences _pref;
  final Logger? _logger;
  final Function() _exitCurrentApp;
  final String _cacheDir;
  final String _downloadUrl;
  final Function(GitHubRelease) _onNewVersionAvailable;
  final Function(DownloadedInstaller) _onDownloadComplete;

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
    bool autoCheck = true,
    bool autoDownload = true,
    required void Function(GitHubRelease) onNewVersionAvailable,
    required void Function(DownloadedInstaller) onDownloadComplete,
  }) : _logger = logger,
       _pref = pref,
       _currentVersion = currentVersion,
       _downloader = downloader,
       _assetName = assetName,
       _repository = repository,
       _exitCurrentApp = exitCurrentApp,
       _cacheDir = cacheDir,
       _downloadUrl = downloadUrl,
       _onNewVersionAvailable = onNewVersionAvailable,
       _onDownloadComplete = onDownloadComplete,
       _autoCheck = autoCheck,
       _autoDownload = autoDownload {
    _resetTimer();
  }

  void _setDownloadedInstallerPath(DownloadedInstaller? installer) {
    if (installer == null) {
      _pref.remove('downloadedInstaller');
    } else {
      _pref.setString('downloadedInstaller', jsonEncode(installer.toJson()));
    }
  }

  String? get _skipVersion {
    return _pref.getString('skipVersion');
  }

  void setSkipCurrentVersion() async {
    final localInstaller = _localInstaller;
    if (localInstaller == null) {
      return;
    }
    _pref.setString('skipVersion', localInstaller.version);
    await _deleteLocalInstaller();
  }

  // version and apk file path
  DownloadedInstaller? get _localInstaller {
    final json = _pref.getString('downloadedInstaller');
    if (json == null) return null;
    final installer = DownloadedInstaller.fromJson(jsonDecode(json));
    return installer;
  }

  bool _autoCheck;
  bool get autoCheckLatestVersion => _autoCheck;
  void setAutoCheckLatestVersion(bool value) {
    _autoCheck = value;
    _resetTimer();
  }

  void _resetTimer() {
    if (_autoDownload || _autoCheck) {
      _startChecking();
    } else {
      _stopChecking();
    }
  }

  bool _autoDownload;
  bool get autoDownload => _autoDownload;
  void setAutoDownload(bool value) {
    _autoDownload = value;
    _resetTimer();
  }

  /// Start automatic update checking
  void _startChecking() {
    if (_timer != null) return;

    _logger?.i('Starting auto-update service');

    // Schedule daily checks (24 hours)
    const dailyInterval = Duration(hours: 24);
    _timer = PeriodicTask(
      sharedPreferences: _pref,
      task: _check,
      period: dailyInterval,
      lastRunKey: 'lastUpdateCheckTime',
    )..start();

    _logger?.i('Checking for updates scheduled to check daily');
  }

  /// Stop automatic update checking
  void _stopChecking() {
    _logger?.i('Stopping checking for updates');
    _timer?.stop();
    _timer = null;
  }

  /// Returns the latest release if there is a new version
  Future<GitHubRelease?> getLatestRelease() async {
    // if (kDebugMode) {
    //   return GitHubRelease(
    //     tagName: '9.9.9',
    //     name: '9.9.9',
    //     prerelease: false,
    //     draft: false,
    //     body: 'Test',
    //     assets: [
    //       GitHubAsset(
    //         name: '9.9.9.apk',
    //         downloadUrl: '',
    //         size: 1000,
    //         contentType: 'application/vnd.android.package-archive',
    //         updatedAt: DateTime.now(),
    //       ),
    //     ],
    //     publishedAt: DateTime.now(),
    //   );
    // }
    return getLatestReleaseContainingNewerAndroidApk(
      _repository,
      _currentVersion,
      _assetName,
    );
  }

  /// Check for updates and install if there is a new version
  Future<void> _check() async {
    _logger?.i('Checking for updates');
    // if local installer exist
    final localInstaller = _localInstaller;
    if (localInstaller != null) {
      if (localInstaller.version == _currentVersion ||
          !versionNewerThan(localInstaller.version, _currentVersion)) {
        _deleteLocalInstaller();
        return;
      } else {
        return _onDownloadComplete(localInstaller);
      }
    }

    final release = await getLatestRelease();
    if (release != null) {
      if (_skipVersion == release.version) {
        _logger?.d('skip this version ${release.version}');
        return;
      }
      if (autoDownload) {
        await _downloadToLocal(release);
      } else {
        _onNewVersionAvailable(release);
      }
    }
  }

  Future<void> _downloadToLocal(GitHubRelease release) async {
    try {
      final newestDownloadUrl = '$_downloadUrl/$_assetName';
      DownloadedInstaller? installer;
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
          installer = DownloadedInstaller(
            version: release.version,
            path: newApkFile.path,
            newFeatures: release.body,
          );
          _setDownloadedInstallerPath(installer);
        });
      } else if (Platform.isWindows) {
        final downloadDest = join(_cacheDir, '${release.version}_$_assetName');
        await _downloader(newestDownloadUrl, downloadDest);
        installer = DownloadedInstaller(
          version: release.version,
          path: downloadDest,
          newFeatures: release.body,
        );
        _setDownloadedInstallerPath(installer);
      } else if (Platform.isLinux) {
        _logger?.d('Downloading installer for Linux $newestDownloadUrl');
        final downloadDest = join(_cacheDir, '${release.version}_$_assetName');
        await _downloader(newestDownloadUrl, downloadDest);
        installer = DownloadedInstaller(
          version: release.version,
          path: downloadDest,
          newFeatures: release.body,
        );
        _setDownloadedInstallerPath(installer);
      }
      _onDownloadComplete(installer!);
    } catch (e, stackTrace) {
      _logger?.e('_downloadToLocal', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _deleteLocalInstaller() async {
    final localInstaller = _localInstaller;
    if (localInstaller != null) {
      final apkFile = File(localInstaller.path);
      if (apkFile.existsSync()) {
        apkFile.deleteSync();
      }
      _setDownloadedInstallerPath(null);
    }
  }

  Future<void> updateToRelease(GitHubRelease release) async {
    return _downloadToLocal(release);
  }

  /// Install the downloaded installer
  Future<void> installLocalInstaller() async {
    final installer = _localInstaller;
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
}

class HasNewerVersionDialog extends StatelessWidget {
  const HasNewerVersionDialog({
    super.key,
    required this.release,
    required this.setSkipCurrentVersion,
    required this.updateToRelease,
  });
  final GitHubRelease release;
  final Function() setSkipCurrentVersion;
  final Function(GitHubRelease) updateToRelease;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        AppLocalizations.of(context)!.hasNewerVersionDialog(release.tagName),
      ),
      content: Text(release.body),
      actions: [
        OutlinedButton(
          onPressed: () async {
            Navigator.of(context).pop();
            setSkipCurrentVersion();
          },
          child: Text(AppLocalizations.of(context)!.skipThisVersion),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(context).pop();
            try {
              await updateToRelease(release);
            } catch (e) {
              if (context.mounted) {
                showAlertDialog(
                  context,
                  AppLocalizations.of(context)!.installFailed(e.toString()),
                );
              }
            }
          },
          child: Text(AppLocalizations.of(context)!.okay),
        ),
      ],
    );
  }
}

class InstallNewerVersionDialog extends StatelessWidget {
  const InstallNewerVersionDialog({
    super.key,
    required this.downloadedInstaller,
    required this.setSkipCurrentInstaller,
    required this.installLocalInstaller,
  });
  final DownloadedInstaller downloadedInstaller;
  final Function() setSkipCurrentInstaller;
  final Function() installLocalInstaller;

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
            setSkipCurrentInstaller();
          },
          child: Text(AppLocalizations.of(context)!.skipThisVersion),
        ),
        FilledButton.tonal(
          onPressed: () async {
            Navigator.of(context).pop();
            try {
              await installLocalInstaller();
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
