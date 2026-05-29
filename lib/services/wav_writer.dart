import 'dart:io';
import 'dart:typed_data';

/// Production-grade WAV writer with:
/// - 64KB write buffer to minimize disk I/O syscalls
/// - Periodic header checkpointing for crash-safe recordings
/// - Clean RIFF/WAVE spec implementation
class WavWriter {
  final File file;
  late RandomAccessFile _raf;
  int _dataSize = 0;
  final int sampleRate;
  final int channels;

  // 64KB buffer — flushes every ~700ms at 44.1kHz mono 16-bit
  static const int _bufferThreshold = 65536;
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  WavWriter(String path, {this.sampleRate = 44100, this.channels = 1})
      : file = File(path);

  Future<void> open() async {
    if (await file.exists()) {
      await file.delete();
    }
    await file.create(recursive: true);
    _raf = await file.open(mode: FileMode.write);
    // Write zeroed-out 44-byte placeholder header immediately
    await _raf.writeFrom(Uint8List(44));
  }

  /// Buffer incoming PCM bytes and flush to disk in large chunks.
  Future<void> write(Uint8List pcmData) async {
    _buffer.add(pcmData);
    _dataSize += pcmData.length;

    if (_buffer.length >= _bufferThreshold) {
      await _flushBuffer();
    }
  }

  /// Flush the in-memory buffer to disk without closing the file.
  Future<void> _flushBuffer() async {
    if (_buffer.isEmpty) return;
    final data = _buffer.takeBytes();
    await _raf.writeFrom(data);
  }

  /// Crash-safe header checkpoint. Call periodically (e.g., every 5s) while recording.
  /// Writes the current data size into the RIFF header in place so the file is
  /// always playable even if the app is killed before [close] is called.
  Future<void> checkpoint() async {
    // Flush pending buffer first so the header reflects all written data
    await _flushBuffer();
    final currentPos = await _raf.position();
    await _writeHeader();
    // Seek back to the end to continue writing
    await _raf.setPosition(currentPos);
  }

  /// Finalize the WAV file: flush buffer, write correct header, close handle.
  Future<void> close() async {
    await _flushBuffer();
    await _writeHeader();
    await _raf.close();
  }

  /// Seeks to position 0 and writes the complete RIFF/WAVE/fmt/data header.
  Future<void> _writeHeader() async {
    final header = ByteData(44);

    // RIFF chunk descriptor
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, _dataSize + 36, Endian.little); // ChunkSize
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // fmt sub-chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little);    // Subchunk1Size (PCM = 16)
    header.setUint16(20, 1, Endian.little);     // AudioFormat (1 = PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * channels * 2, Endian.little); // ByteRate
    header.setUint16(32, channels * 2, Endian.little); // BlockAlign
    header.setUint16(34, 16, Endian.little);    // BitsPerSample

    // data sub-chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, _dataSize, Endian.little); // Subchunk2Size

    await _raf.setPosition(0);
    await _raf.writeFrom(header.buffer.asUint8List());
  }
}
