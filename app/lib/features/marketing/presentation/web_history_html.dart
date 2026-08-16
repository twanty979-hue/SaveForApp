import 'dart:html' as html;

void pushWebPath(String path) {
  if (html.window.location.pathname != path) {
    html.window.history.pushState(null, '', path);
  }
}

void replaceWebPath(String path) {
  if (html.window.location.pathname != path) {
    html.window.history.replaceState(null, '', path);
  }
}
