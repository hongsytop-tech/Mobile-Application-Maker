class UpdateInfo {
  final int latestBuild;
  final int currentBuild;
  final String name;
  final String apkUrl;
  final int? apkSizeBytes;
  final String releaseUrl;
  final String releaseNotes;

  const UpdateInfo({
    required this.latestBuild,
    required this.currentBuild,
    required this.name,
    required this.apkUrl,
    this.apkSizeBytes,
    required this.releaseUrl,
    required this.releaseNotes,
  });

  bool get hasUpdate => latestBuild > currentBuild;
}
