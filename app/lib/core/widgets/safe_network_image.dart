import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../network/web_helper.dart' as web_helper;

class SafeNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const SafeNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final webWidget = web_helper.buildWebImage(url, width: width, height: height, fit: fit);
      if (webWidget != null) {
        return Stack(
          fit: StackFit.passthrough,
          children: [
            webWidget,
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
          ],
        );
      }
    }
    
    final apiClient = ApiClient();
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      headers: apiClient.imageHeaders(url),
      errorBuilder: errorBuilder,
    );
  }
}
