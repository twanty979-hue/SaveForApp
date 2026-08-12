import 'dart:html' as html;
import 'package:flutter/widgets.dart';
import 'dart:ui_web' as ui_web;

void redirectWindow(String url) {
  html.window.location.assign(url);
}

Widget? buildWebImage(String url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  final viewType = 'web-image-${url.hashCode}';
  try {
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => html.ImageElement()
        ..src = url
        ..referrerPolicy = 'no-referrer'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = 'none'
        ..style.objectFit = fit == BoxFit.cover ? 'cover' : 'contain',
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
