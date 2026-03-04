enum DownloadStatus { none, queued, downloading, completed, failed, deleted }

class VideoItem {
  final String bvid;
  final String title;
  final String author;
  final int authorMid;
  final String thumbnail;
  final String pubDate;
  final String description;
  final String link;
  DownloadStatus downloadStatus;
  double downloadProgress;
  String? localPath;
  String? downloadedAt;

  VideoItem({
    required this.bvid,
    required this.title,
    required this.author,
    this.authorMid = 0,
    this.thumbnail = '',
    this.pubDate = '',
    this.description = '',
    this.link = '',
    this.downloadStatus = DownloadStatus.none,
    this.downloadProgress = 0.0,
    this.localPath,
    this.downloadedAt,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      bvid: json['bvid'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      authorMid: json['authorMid'] ?? 0,
      thumbnail: json['thumbnail'] ?? '',
      pubDate: json['pubDate'] ?? '',
      description: json['description'] ?? '',
      link: json['link'] ?? '',
      downloadStatus: DownloadStatus.values[json['downloadStatus'] ?? 0],
      downloadProgress: (json['downloadProgress'] ?? 0.0).toDouble(),
      localPath: json['localPath'],
      downloadedAt: json['downloadedAt'],
    );
  }

  Map<String, dynamic> toJson() => {
        'bvid': bvid,
        'title': title,
        'author': author,
        'authorMid': authorMid,
        'thumbnail': thumbnail,
        'pubDate': pubDate,
        'description': description,
        'link': link,
        'downloadStatus': downloadStatus.index,
        'downloadProgress': downloadProgress,
        'localPath': localPath,
        'downloadedAt': downloadedAt,
      };
}
