import 'dart:html' as html;
import 'package:flutter/widgets.dart';
import 'dart:ui_web' as ui_web;

void redirectWindow(String url) {
  html.window.location.assign(url);
}

Widget? buildWebImage(String url, {double? width, double? height, BoxFit fit = BoxFit.cover, bool isCircle = false}) {
  final viewType = 'web-img-v4-${url.hashCode}-$isCircle';
  try {
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final img = html.ImageElement()
          ..src = url
          ..referrerPolicy = 'no-referrer'
          ..style.position = 'absolute'
          ..style.top = '0'
          ..style.left = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..style.margin = '0'
          ..style.padding = '0'
          ..style.objectFit = fit == BoxFit.cover ? 'cover' : 'contain';
        if (isCircle) {
          img.style.borderRadius = '50%';
        }
        return img;
      },
    );
  } catch (e) {
    // Ignore already registered view type error
  }
  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: viewType),
  );
}
