A cross platform dart package to extract meta data from flac files.

sample

```dart

import 'dart:io';

import 'package:flac_metadata/flacstream.dart';

Future<void> main(List<String> arguments) async {
  var file = 'sample.flac';

  var flac = FlacInfo(File(file));
  var metadatas = await flac.readMetadatas();
  print(metadatas);
}


```