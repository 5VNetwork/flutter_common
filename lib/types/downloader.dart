abstract class Downloader {
  /// Downloads a file from the given URL to the given destination.
  ///
  /// if the file already exists, it will be overwritten.
  Future<void> download(String url, String dest);

  Future<void> downloadMulti(List<String> urls, String dest);
}
