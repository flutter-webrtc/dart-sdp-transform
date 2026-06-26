import 'package:test/test.dart';

import '../lib/sdp_transform.dart';

// Reproduces the ICE ufrag corruption: the parser runs every captured token
// through toIntIfInt(), which coerces any int-parseable string to an int with
// NO round-trip guard. So a numeric / hex / leading-zero ICE ufrag loses
// characters (0048 -> 48, 0X48 -> 72 because Dart parses 0x/0X as hex) and, on
// write, emerges shorter than the 4-char minimum that WebRTC requires.
//
// The original JavaScript sdp-transform guards this:
//   toIntIfInt = v => String(Number(v)) === v ? Number(v) : v;
// This Dart port dropped the `String(Number(v)) === v` check.

String _sdp(String ufrag, String pwd) =>
    'v=0\r\n'
    'o=- 1 2 IN IP4 127.0.0.1\r\n'
    's=-\r\n'
    't=0 0\r\n'
    'm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n'
    'c=IN IP4 0.0.0.0\r\n'
    'a=ice-ufrag:$ufrag\r\n'
    'a=ice-pwd:$pwd\r\n'
    'a=rtpmap:111 opus/48000/2\r\n';

const _pwd = 'i/t5V07djNTEAYr75Avl1rCf';

void main() {
  group('parse keeps ICE ufrag as a verbatim string', () {
    for (final ufrag in ['0048', '0123', '0001', '0000', '0X48', '7200', 'fMNB', 'la/s']) {
      test('ufrag "$ufrag"', () {
        final session = parse(_sdp(ufrag, _pwd));
        final media = (session['media'] as List).first as Map<String, dynamic>;
        expect(media['iceUfrag'].toString(), ufrag, reason: 'parser coerced ufrag via toIntIfInt');
      });
    }
  });

  group('parse -> write round-trip preserves ICE ufrag', () {
    for (final ufrag in ['0048', '0123', '0001', '0000', '0X48', '7200', 'fMNB', 'la/s']) {
      test('ufrag "$ufrag"', () {
        final out = write(parse(_sdp(ufrag, _pwd)), null);
        expect(out, contains('a=ice-ufrag:$ufrag'), reason: 'round-trip corrupted ufrag');

        final outUfrag = RegExp(r'a=ice-ufrag:(\S*)').firstMatch(out)?.group(1) ?? '';
        expect(outUfrag.length, greaterThanOrEqualTo(4),
            reason: 'ufrag "$ufrag" emerged as "$outUfrag" (< 4 chars) - WebRTC would reject it');
      });
    }
  });
}
