import './grammar.dart' show grammar;
import 'dart:convert';

dynamic toIntIfInt(v) {
  return v != null ? int.tryParse(v) != null ? int.parse(v) : v : null;
}

void attachProperties(
    Iterable<RegExpMatch> match, Map location, names, rawName) {
  if ((rawName != null && rawName.length > 0) &&
      (names == null || names.length == 0)) {
    match.forEach((m) {
      location[rawName] = toIntIfInt(m.groupCount == 0 ? m.input : m.group(1));
    });
  } else {
    match.forEach((m) {
      for (var i = 0; i < m.groupCount; i++) {
        location[names[i].toString()] = toIntIfInt(m.group(i + 1));
      }
    });
  }
}

void parseReg(obj, location, content) {
  var needsBlank = obj['name'] != null && obj['names'] != null;
  if (obj['push'] != null && location[obj['push']] == null) {
    location[obj['push']] = [];
  } else if (needsBlank && location[obj['name']] == null) {
    location[obj['name']] = {};
  }

  var keyLocation = obj['push'] != null
      ? {}
      : // blank object that will be pushed
      needsBlank
          ? location[obj['name']]
          : location; // otherwise, named location or root

  attachProperties(RegExp(obj['reg']).allMatches(content), keyLocation,
      obj['names'], obj['name']);

  if (obj['push'] != null) {
    location[obj['push']].add(keyLocation);
  }
}

Map<String, dynamic> parse(String sdp) {
  var session = Map<String, dynamic>();
  var medias = [];

  var location =
      session; // points at where properties go under (one of the above)

  print(sdp);
  // parse lines we understand
  LineSplitter().convert(sdp).forEach((l) {
    if (l != '') {
      var type = l[0];
      var content = l.substring(2);
      if (type == 'm') {
        Map<dynamic, dynamic> media = new Map();
        media['rtp'] = [];
        media['fmtp'] = [];
        location = media; // point at latest media line
        medias.add(media);
      }
      for (var j = 0; j < grammar[type].length; j += 1) {
        var obj = grammar[type][j];
        if (obj['reg'] == null) {
          location[obj['name']] = content;
          continue;
        }

        if (obj['reg'] is RegExp) {
          if ((obj['reg'] as RegExp).hasMatch(content)) {
            parseReg(obj, location, content);
            return;
          }
        } else if (RegExp(obj['reg']).hasMatch(content)) {
          parseReg(obj, location, content);
          return;
        }
      }
    }
  });
  session['media'] = medias; // link it up
  return session;
}

Map<dynamic, dynamic> parseParams(str) {
  Map<dynamic, dynamic> params = new Map();
  str.split(new RegExp(r';').pattern).forEach((line) {
    List<String> kv = line.split(new RegExp(r'=').pattern);
    params[kv[0]] = toIntIfInt(kv[1]);
  });
  return params;
}

List<String> parsePayloads(str) {
  return str.split(' ');
}

List<String> parseRemoteCandidates(str) {
  var candidates = [];
  var parts = str.split(' ').forEach(toIntIfInt);
  for (var i = 0; i < parts.length; i += 3) {
    candidates
        .add({'component': parts[i], 'ip': parts[i + 1], 'port': parts[i + 2]});
  }
  return candidates;
}

List<String> parseImageAttributes(str) {
  var attributes = [];
  str.split(' ').forEach((item) {
    Map<dynamic, dynamic> params = new Map();
    item.substring(1, item.length - 1).split(',').forEach((attr) {
      List<String> kv = attr.split(new RegExp(r'=').pattern);
      params[kv[0]] = toIntIfInt(kv[1]);
    });
    attributes.add(params);
  });
  return attributes;
}

List<String> parseSimulcastStreamList(str) {
  var attributes = [];
  str.split(';').forEach((stream) {
    var scids = [];
    stream.split(',').forEach((format) {
      var scid, paused = false;
      if (format[0] != '~') {
        scid = toIntIfInt(format);
      } else {
        scid = toIntIfInt(format.substring(1, format.length));
        paused = true;
      }
      scids.add({"scid": scid, "paused": paused});
    });
    attributes.add(scids);
  });
  return attributes;
}
