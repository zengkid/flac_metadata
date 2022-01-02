import 'dart:convert';
import 'dart:typed_data';

import 'package:hex/hex.dart';

import 'flacstream.dart';

/// flac block type
enum BlockType {
  STREAMINFO,
  PADDING,
  APPLICATION,
  SEEKTABLE,
  VORBIS_COMMENT,
  CUESHEET,
  PICTURE
}

/// Flac Metadata
abstract class Metadata {
  BlockType blockType;
  bool isLast;
  int dataLength;
  late StreamReader _reader;

  Metadata(this.blockType, this.isLast, Uint8List rawData, this.dataLength) {
    _reader = StreamReader(rawData, dataLength);
  }
}

/// flac stream info block type
class StreamInfo extends Metadata {
  static const MIN_BLOCK_SIZE = 16; // bits
  static const MAX_BLOCK_SIZE = 16; // bits
  static const MIN_FRAME_SIZE = 24; // bits
  static const MAX_FRAME_SIZE = 24; // bits
  static const SAMPLE_RATE = 20; // bits
  static const CHANNELS_SIZE = 3; // bits
  static const BITS_PER_SAMPLE_SIZE = 5; // bits
  static const TOTAL_SAMPLES_SIZE = 36; // bits
  static const MD5SUM_SIZE = 128; // bits

  late int minBlockSize;
  late int maxBlockSize;
  late int minFrameSize;
  late int maxFrameSize;
  late int sampleRate;
  late int channels;
  late int bitsPerSample;
  late int totalSamples;
  late String md5sum;

  StreamInfo(bool isLast, Uint8List rawData, int dataLength)
      : super(BlockType.STREAMINFO, isLast, rawData, dataLength) {
    minBlockSize = _reader.getInt(MIN_BLOCK_SIZE);
    maxBlockSize = _reader.getInt(MAX_BLOCK_SIZE);
    minFrameSize = _reader.getInt(MIN_FRAME_SIZE);
    maxFrameSize = _reader.getInt(MAX_FRAME_SIZE);
    sampleRate = _reader.getInt(SAMPLE_RATE);
    channels = _reader.getInt(CHANNELS_SIZE) + 1;
    bitsPerSample = _reader.getInt(BITS_PER_SAMPLE_SIZE) + 1;
    totalSamples = _reader.getInt(TOTAL_SAMPLES_SIZE);
    var md5 = _reader.getUint8List(MD5SUM_SIZE);
    md5sum = HEX.encode(md5.toList());
  }

  @override
  String toString() {
    return 'StreamInfo{minBlockSize: $minBlockSize, maxBlockSize: $maxBlockSize, minFrameSize: $minFrameSize, maxFrameSize: $maxFrameSize, sampleRate: $sampleRate, channels: $channels, bitsPerSample: $bitsPerSample, totalSamples: $totalSamples, md5sum: $md5sum}';
  }
}

/// flac padding block type
class Padding extends Metadata {
  late String padding;

  Padding(bool isLast, Uint8List rawData, int dataLength)
      : super(BlockType.PADDING, isLast, rawData, dataLength) {
    padding = _reader.getString(dataLength);
  }

  @override
  String toString() {
    return 'Padding{padding: $padding}';
  }
}

/// flac application block type
class Application extends Metadata {
  static const APPLICATION_ID_SIZE = 32;
  late String id;
  late String data;

  Application(bool isLast, Uint8List rawData, int dataLength)
      : super(BlockType.APPLICATION, isLast, rawData, dataLength) {
    id = _reader.getString(APPLICATION_ID_SIZE);
    data = _reader.getString(dataLength * 8 - APPLICATION_ID_SIZE);
  }

  @override
  String toString() {
    return 'Application{id: $id, data: $data}';
  }
}

/// flac seek table block type
class SeekTable extends Metadata {
  var points = <SeekPoint>[];

  SeekTable(bool isLast, Uint8List rawData, int dataLength)
      : super(BlockType.SEEKTABLE, isLast, rawData, dataLength) {
    var pointNum = dataLength ~/ 18;
    for (var i = 0; i < pointNum; i++) {
      var sampleNumber = _reader.getInt(SeekPoint.SAMPLE_NUMBER_SIZE);
      var streamOffset = _reader.getInt(SeekPoint.STREAM_OFFSET_SIZE);
      var frameSamples = _reader.getInt(SeekPoint.FRAME_SAMPLES_SIZE);

      var point = SeekPoint(sampleNumber, streamOffset, frameSamples);

      points.add(point);
    }
  }

  @override
  String toString() {
    return 'SeekTable{points: $points, length: $dataLength}';
  }
}

class SeekPoint {
  static const SAMPLE_NUMBER_SIZE = 64;
  static const STREAM_OFFSET_SIZE = 64;
  static const FRAME_SAMPLES_SIZE = 16;

  int sampleNumber;
  int streamOffset;
  int frameSamples;

  SeekPoint(this.sampleNumber, this.streamOffset, this.frameSamples);

  @override
  String toString() {
    return 'SeekPoint{sampleNumber: $sampleNumber, streamOffset: $streamOffset, frameSamples: $frameSamples}';
  }
}


/// flac vorbis comment block type
class VorbisComment extends Metadata {
  late int vendorLength;
  late String vendorString;
  late int numComments;
  List<String> comments = [];

  VorbisComment(bool isLast, Uint8List rawData, int dataLength)
      : super(BlockType.VORBIS_COMMENT, isLast, rawData, dataLength) {
    vendorLength = _reader.getLittleEndianInt();
    vendorString = _reader.getString(vendorLength * 8);
    numComments = _reader.getLittleEndianInt();
    for (var i = 0; i < numComments; i++) {
      var len = _reader.getLittleEndianInt();
      if (len > 0) {
        var comment = _reader.getUint8List(len * 8);
        comments.add(utf8.decode(comment));
      }
    }
  }

  @override
  String toString() {
    return 'VorbisComment{vendorLength: $vendorLength, vendorString: $vendorString, numComments: $numComments, comments: $comments}';
  }
}

/// flac picture block type
class Picture extends Metadata {
  late int pictureType;
  late int mimeTypeByteCount;
  late String mimeString;
  late int descStringByteCount;
  String? descString;
  late int picPixelWidth;
  late int picPixelHeight;
  late int picBitsPerPixel;
  late int picColorCount;
  late int picByteCount;

  late Uint8List image;

  Picture(bool isLast, Uint8List rawData, int dataLength)
      : super(BlockType.PICTURE, isLast, rawData, dataLength) {
    pictureType = _reader.getInt(32);
    mimeTypeByteCount = _reader.getInt(32);
    mimeString = _reader.getString(mimeTypeByteCount * 8);
    descStringByteCount = _reader.getInt(32);
    if (descStringByteCount > 0) {
      var data = _reader.getUint8List(descStringByteCount * 8);
      descString = utf8.decode(data);
    }
    picPixelWidth = _reader.getInt(32);
    picPixelHeight = _reader.getInt(32);
    picBitsPerPixel = _reader.getInt(32);
    picColorCount = _reader.getInt(32);
    picByteCount = _reader.getInt(32);
    image = _reader.getUint8List(picByteCount * 8);
  }

  @override
  String toString() {
    return 'Picture{pictureType: $pictureType, mimeTypeByteCount: $mimeTypeByteCount, mimeString: $mimeString, descStringByteCount: $descStringByteCount, descString: $descString, picPixelWidth: $picPixelWidth, picPixelHeight: $picPixelHeight, picBitsPerPixel: $picBitsPerPixel, picColorCount: $picColorCount, picByteCount: $picByteCount}';
  }
}

/// flac cue sheet block type
class CueSheet extends Metadata {
  static const MEDIA_CATALOG_NUMBER_SIZE = 128 * 8; // bits
  static const LEAD_IN_SIZE = 64; // bits
  static const IS_CD_SIZE = 1; // bit
  static const RESERVED_SIZE = 7 + 258 * 8; // bits
  static const NUM_TRACKS_SIZE = 8; // bits

  late Uint8List mediaCatalogNumber;
  int leadIn = 0; // The number of lead-in samples.
  bool isCD =
      false; // true if CUESHEET corresponds to a Compact Disc, else false
  int numTracks = 0; // The number of tracks.
  var tracks = <CueTrack>[];

  // NULL if num_tracks == 0, else pointer to array of tracks
  CueSheet(bool isLast, Uint8List rawData, int dataLength)
      : super(BlockType.CUESHEET, isLast, rawData, dataLength) {
    mediaCatalogNumber = _reader.getUint8List(MEDIA_CATALOG_NUMBER_SIZE);
    leadIn = _reader.getInt(LEAD_IN_SIZE);
    isCD = _reader.getInt(IS_CD_SIZE) != 0;
    _reader.skip(RESERVED_SIZE);
    numTracks = _reader.getInt(NUM_TRACKS_SIZE);
    if (numTracks > 0) {
      for (var i = 0; i < numTracks; i++) {
        var cueTrack = CueTrack(_reader);
        tracks.add(cueTrack);
      }
    }
  }

  @override
  String toString() {
    return 'CueSheet{leadIn: $leadIn, isCD: $isCD, numTracks: $numTracks, tracks: $tracks}';
  }
}

class CueTrack {
  static const OFFSET_SIZE = 64; // bits
  static const NUMBER_SIZE = 8; // bits
  static const ISRC_SIZE = 12 * 8; // bits
  static const TYPE_SIZE = 1; // bit
  static const PRE_EMPHASIS_SIZE = 1; // bit
  static const RESERVED_SIZE = 6 + 13 * 8; // bits
  static const NUM_INDICES_SIZE = 8; // bits

  StreamReader reader;
  late int offset; // Track offset in samples, relative to the beginning of the FLAC audio stream.
  late int number; // The track number.
  Uint8List isrc = Uint8List(13); // Track ISRC.
  late int type; // The track type: 0 for audio, 1 for non-audio.
  late int preEmphasis; // The pre-emphasis flag: 0 for no pre-emphasis, 1 for pre-emphasis.
  late int numIndices; // The number of track index points.
  var indices = <
      CueIndex>[]; //// NULL if num_indices == 0, else pointer to array of index points.

  CueTrack(this.reader) {
    offset = reader.getInt(CueTrack.OFFSET_SIZE);
    number = reader.getInt(CueTrack.NUMBER_SIZE);
    isrc = reader.getUint8List(CueTrack.ISRC_SIZE);
    type = reader.getInt(CueTrack.TYPE_SIZE);
    preEmphasis = reader.getInt(CueTrack.PRE_EMPHASIS_SIZE);
    reader.skip(CueTrack.RESERVED_SIZE);
    numIndices = reader.getInt(CueTrack.NUM_INDICES_SIZE);
    if (numIndices > 0) {
      for (var i = 0; i < numIndices; i++) {
        var cueIndex = CueIndex(reader);
        indices.add(cueIndex);
      }
    }
  }

  @override
  String toString() {
    return 'CueTrack{ offset: $offset, number: $number, type: $type, preEmphasis: $preEmphasis, numIndices: $numIndices, indices: $indices}';
  }
}

class CueIndex {
  static const OFFSET_SIZE = 64; // bits
  static const NUMBER_SIZE = 8; // bits
  static const RESERVED_SIZE = 3 * 8; // bits

  StreamReader reader;
  late int offset; // Offset in samples, relative to the track offset, of the index point.
  late int number;

  CueIndex(this.reader) {
    offset = reader.getInt(OFFSET_SIZE);
    number = reader.getInt(NUMBER_SIZE);
    reader.skip(RESERVED_SIZE);
  }

  @override
  String toString() {
    return 'CueIndex{offset: $offset, number: $number}';
  }
}
