import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/app_model.dart';

class AppIconWidget extends StatelessWidget {
  final TrueNasApp app;
  final String? serverBaseUrl;
  final double size;

  const AppIconWidget({
    super.key,
    required this.app,
    this.serverBaseUrl,
    this.size = 44,
  });

  String _cleanAppName(String raw) {
    return raw
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _resolveUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/') && serverBaseUrl != null && serverBaseUrl!.isNotEmpty) {
      final base = serverBaseUrl!.endsWith('/')
          ? serverBaseUrl!.substring(0, serverBaseUrl!.length - 1)
          : serverBaseUrl!;
      return '$base$trimmed';
    }
    return trimmed;
  }

  bool _isSvgUrl(String url) {
    final uri = Uri.tryParse(url);
    final path = (uri?.path ?? url).toLowerCase();
    return path.endsWith('.svg');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cleanName = _cleanAppName(app.name.isNotEmpty ? app.name : app.id);
    final cdnFallbackUrl = 'https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/$cleanName.png';
    final primaryUrl = (app.icon != null && app.icon!.isNotEmpty) ? _resolveUrl(app.icon!) : null;

    Widget defaultFallback() {
      return Icon(
        Icons.dns_rounded,
        color: app.isRunning ? AppColors.healthy : colorScheme.onSurfaceVariant,
        size: size * 0.55,
      );
    }

    Widget cdnFallback() {
      if (cleanName.isEmpty) return defaultFallback();
      return Padding(
        padding: EdgeInsets.all(size * 0.14),
        child: Image.network(
          cdnFallbackUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => defaultFallback(),
        ),
      );
    }

    Widget iconContent;
    if (primaryUrl != null && primaryUrl.isNotEmpty) {
      if (_isSvgUrl(primaryUrl)) {
        iconContent = Padding(
          padding: EdgeInsets.all(size * 0.14),
          child: SvgPicture.network(
            primaryUrl,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => cdnFallback(),
            errorBuilder: (_, __, ___) => cdnFallback(),
          ),
        );
      } else {
        iconContent = Padding(
          padding: EdgeInsets.all(size * 0.14),
          child: Image.network(
            primaryUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => cdnFallback(),
          ),
        );
      }
    } else {
      iconContent = cdnFallback();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: (app.isRunning ? AppColors.healthy : colorScheme.onSurfaceVariant)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(child: iconContent),
    );
  }
}
