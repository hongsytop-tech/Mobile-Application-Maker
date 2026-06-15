import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class BookCover extends StatelessWidget {
  final String url;
  final double width;
  final double height;

  const BookCover({
    super.key,
    required this.url,
    this.width = 56,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: url.isEmpty
          ? Container(
              width: width,
              height: height,
              color: Colors.grey.shade300,
              child: const Icon(Icons.menu_book_outlined),
            )
          : CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: width,
                height: height,
                color: Colors.grey.shade200,
              ),
              errorWidget: (_, __, ___) => Container(
                width: width,
                height: height,
                color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
    );
  }
}
