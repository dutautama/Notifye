import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../services/attachment_service.dart';

/// Menampilkan gambar lampiran lokal dari path relatif.
class AttachmentImage extends StatelessWidget {
  const AttachmentImage(this.relativePath, {super.key, this.size = 48, this.fallback = Icons.image_outlined});

  final String? relativePath;
  final double size;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(fallback, size: size * 0.5),
    );
    if (relativePath == null) return placeholder;
    return FutureBuilder<File>(
      future: AttachmentService.fileFor(relativePath!),
      builder: (context, snap) {
        if (!snap.hasData) return placeholder;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(snap.data!,
              width: size, height: size, fit: BoxFit.cover,
              cacheWidth: (size * 3).round(),
              errorBuilder: (_, _, _) => placeholder),
        );
      },
    );
  }
}
