import 'dart:convert';

enum BookStatus { reading, finished }

class TocItem {
  final String title;
  final bool isRead;

  const TocItem({required this.title, this.isRead = false});

  TocItem copyWith({String? title, bool? isRead}) =>
      TocItem(title: title ?? this.title, isRead: isRead ?? this.isRead);

  Map<String, dynamic> toJson() => {'title': title, 'isRead': isRead};

  factory TocItem.fromJson(Map<String, dynamic> j) =>
      TocItem(title: j['title'] as String, isRead: j['isRead'] as bool? ?? false);
}

class Book {
  final String id;
  final String title;
  final List<String> authors;
  final String publisher;
  final String thumbnail;
  final String description;
  final String isbn;
  final List<TocItem> toc;
  final BookStatus status;
  final DateTime addedAt;
  final DateTime? finishedAt;

  // 외부 메타데이터 (알라딘/교보문고/추후 쿠팡)
  final int? priceStandard;
  final int? priceSales;
  final String? aladinLink;
  final String? kyoboLink;
  final String? coupangLink;

  const Book({
    required this.id,
    required this.title,
    required this.authors,
    required this.publisher,
    required this.thumbnail,
    required this.description,
    required this.isbn,
    required this.toc,
    required this.status,
    required this.addedAt,
    this.finishedAt,
    this.priceStandard,
    this.priceSales,
    this.aladinLink,
    this.kyoboLink,
    this.coupangLink,
  });

  double get progress {
    if (toc.isEmpty) return 0;
    final done = toc.where((e) => e.isRead).length;
    return done / toc.length;
  }

  Book copyWith({
    List<TocItem>? toc,
    BookStatus? status,
    DateTime? finishedAt,
    int? priceStandard,
    int? priceSales,
    String? aladinLink,
    String? kyoboLink,
    String? coupangLink,
  }) {
    return Book(
      id: id,
      title: title,
      authors: authors,
      publisher: publisher,
      thumbnail: thumbnail,
      description: description,
      isbn: isbn,
      toc: toc ?? this.toc,
      status: status ?? this.status,
      addedAt: addedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      priceStandard: priceStandard ?? this.priceStandard,
      priceSales: priceSales ?? this.priceSales,
      aladinLink: aladinLink ?? this.aladinLink,
      kyoboLink: kyoboLink ?? this.kyoboLink,
      coupangLink: coupangLink ?? this.coupangLink,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'authors': authors,
        'publisher': publisher,
        'thumbnail': thumbnail,
        'description': description,
        'isbn': isbn,
        'toc': toc.map((e) => e.toJson()).toList(),
        'status': status.name,
        'addedAt': addedAt.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'priceStandard': priceStandard,
        'priceSales': priceSales,
        'aladinLink': aladinLink,
        'kyoboLink': kyoboLink,
        'coupangLink': coupangLink,
      };

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as String,
        title: j['title'] as String,
        authors: (j['authors'] as List).cast<String>(),
        publisher: j['publisher'] as String? ?? '',
        thumbnail: j['thumbnail'] as String? ?? '',
        description: j['description'] as String? ?? '',
        isbn: j['isbn'] as String? ?? '',
        toc: (j['toc'] as List? ?? [])
            .map((e) => TocItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        status: BookStatus.values.byName(j['status'] as String? ?? 'reading'),
        addedAt: DateTime.parse(j['addedAt'] as String),
        finishedAt: j['finishedAt'] == null
            ? null
            : DateTime.parse(j['finishedAt'] as String),
        priceStandard: j['priceStandard'] as int?,
        priceSales: j['priceSales'] as int?,
        aladinLink: j['aladinLink'] as String?,
        kyoboLink: j['kyoboLink'] as String?,
        coupangLink: j['coupangLink'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());
  factory Book.fromJsonString(String s) =>
      Book.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
