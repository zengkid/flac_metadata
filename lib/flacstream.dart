import 'dart:io';
import 'dart:typed_data';

import 'metadata.dart';

class FlacInfo {
  final File _file;

  FlacInfo(this._file);

  Future<List<Metadata>> readMetadatas() async {
    var rf = _file.openSync();
    var metadatas = <Metadata>[];
    var fileType = rf.readSync(4);
    if (String.fromCharCodes(fileType) == 'fLaC') {
      var isLast = false;
      while (!isLast) {
        var metaBlockHeader = rf.readSync(1);
        var header = metaBlockHeader[0];
        isLast = ((header & 0x80) >> 7) == 1;
        var type = header & 0x7F;
        var sizes = rf.readSync(3);
        var dataLength = (sizes[0] << 16) + (sizes[1] << 8) + sizes[2];
        var metadataBytes = rf.readSync(dataLength);
        var metadata = _createMetadata(type, isLast, metadataBytes, dataLength);
        metadatas.add(metadata);
      }
    }
    return metadatas;
  }

  Metadata _createMetadata(
      int blockType, bool isLast, Uint8List rawData, int length) {
    Metadata metadata;
    if (blockType == 0) {
      metadata = StreamInfo(isLast, rawData, length);
    } else if (blockType == 1) {
      metadata = Padding(isLast, rawData, length);
    } else if (blockType == 2) {
      metadata = Application(isLast, rawData, length);
    } else if (blockType == 3) {
      metadata = SeekTable(isLast, rawData, length);
    } else if (blockType == 4) {
      metadata = VorbisComment(isLast, rawData, length);
    } else if (blockType == 5) {
      metadata = CueSheet(isLast, rawData, length);
    } else if (blockType == 6) {
      metadata = Picture(isLast, rawData, length);
    }
    return metadata;
  }
}

class StreamReader {
  final Uint8List _rawData;
  int dataLength;
  String _bitData;
  int _index = 0;

  StreamReader(this._rawData, this.dataLength) {
    _bitData = _rawData.map((e) => e.toRadixString(2).padLeft(8, '0')).join('');
  }

  int getInt(int length) {
    var value =
        int.parse(_bitData.substring(_index, _index + length), radix: 2);
    _index = _index + length;
    return value;
  }

  String getBits(int length) {
    var value = _bitData.substring(_index, _index + length);
    _index = _index + length;
    return value;
  }

  void skip(int length) {
    _index = _index + length;
  }

  String getString(int length) {
    var data = getUint8List(length);
    return String.fromCharCodes(data);
  }

  List<int> getInts(int length) {
    var start = _index ~/ 8;
    var end = start + length ~/ 8;

    var data = _rawData.sublist(start, end);
    _index = _index + length;
    return data;
  }

  Uint8List getUint8List(int length) {
    var ints = getInts(length);
    var data = Uint8List.fromList(ints);
    return data;
  }

  int getLittleEndianInt() {
    var result = getInt(8) | getInt(8) << 8 | getInt(8) << 16 | getInt(8) << 24;
    return result;
  }
}
