import 'dart:io';
import 'dart:convert';
import 'package:sdp_transform/sdp_transform.dart';

main() {
  new File('./test/ssrc.sdp').readAsString().then((String contents) {
    print('original sdp => ' + contents);
    var session = parse(contents);
    print('convert to json => ' + json.encode(session));
    var sdp = write(session, null);
    print('convert to sdp => ' + sdp);
  });
}