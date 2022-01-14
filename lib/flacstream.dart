import 'dart:io';
import 'dart:typed_data';

import 'metadata.dart';

/// Flac file format info
class FlacInfo {
  final File _file;

  FlacInfo(this._file);

  /// reade all metadata from flac file
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
    } else {
      throw ArgumentError('Illegal blockType.');
    }
    return metadata;
  }
}

/// byte to bit string reader
class StreamReader {
  final Uint8List _rawData;
  int dataLength;
  late String _bitData;
  int _index = 0;

  /// constructor
  ///
  /// [_rawData] is file byte data, [dataLength] is max length
  StreamReader(this._rawData, this.dataLength) {
    _bitData = _rawData.map((e) => e.toRadixString(2).padLeft(8, '0')).join('');
  }

  ///  int value with the bit [length]
  ///
  /// get the bit with [length], and then covert bits to int value.
  int getInt(int length) {
    var value =
        int.parse(_bitData.substring(_index, _index + length), radix: 2);
    _index = _index + length;
    return value;
  }

  /// get bit string value with [length] bits
  String getBits(int length) {
    var value = _bitData.substring(_index, _index + length);
    _index = _index + length;
    return value;
  }

  /// skip bits with [length]
  void skip(int length) {
    _index = _index + length;
  }

  /// get string value with [length]
  ///
  /// [length] must 8^n, get [length ~/ 8] bits to bytes
  /// and then covert the bytes to a string.
  String getString(int length) {
    var data = getUint8List(length);
    return String.fromCharCodes(data);
  }

  /// get int value with [length] bits.
  ///
  /// [length] must 8^n,  get [length ~/ 8] List<int>
  List<int> getInts(int length) {
    var start = _index ~/ 8;
    var end = start + length ~/ 8;

    var data = _rawData.sublist(start, end);
    _index = _index + length;
    return data;
  }

  /// covert [getInts] return type List<int> to [Uint8List]
  Uint8List getUint8List(int length) {
    var ints = getInts(length);
    var data = Uint8List.fromList(ints);
    return data;
  }

  /// get 4 bytes and then covert to little endian int.
  int getLittleEndianInt() {
    var result = getInt(8) | getInt(8) << 8 | getInt(8) << 16 | getInt(8) << 24;
    return result;
  }
}
