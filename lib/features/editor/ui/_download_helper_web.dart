/// Web implementation of file download using package:web.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Download a JSON file on web platforms.
void downloadJsonFile(String filename, String content) {
  final encoder = web.TextEncoder();
  final bytes = encoder.encode(content);
  final blob = web.Blob(
    [bytes].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
