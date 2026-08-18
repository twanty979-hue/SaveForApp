import 'package:flutter/material.dart';
import '../network/api_client.dart';

class SafeNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool isCircle;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const SafeNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.isCircle = false,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();
    final image = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      headers: apiClient.imageHeaders(url),
      errorBuilder: errorBuilder,
    );

    return isCircle ? ClipOval(child: image) : image;
  }
}
