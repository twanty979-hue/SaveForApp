import 'dart:html' as html;
import 'package:flutter/widgets.dart';
import 'dart:ui_web' as ui_web;

void redirectWindow(String url) {
  html.window.location.assign(url);
}

Widget? buildWebImage(String url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  // Use a new version string in viewType to force Flutter Web to register this new factory,
  // bypassing any cached factory from previous hot-restarts.
  final viewType = 'web-img-v3-${url.hashCode}';
  try {
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => html.ImageElement()
        ..src = url
        ..referrerPolicy = 'no-referrer'
        ..style.display = 'block'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..style.margin = '0'
        ..style.padding = '0'
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
