import 'dart:io';
import 'dart:convert';
import '../lib/src/parser.dart';

main(List<String> arguments) {
  new File('./test/ssrc.sdp').readAsString().then((String contents) {
    print('sdp => ' + contents);
    var session = parse(contents);
    print('json => ' + json.encode(session));
  });
}