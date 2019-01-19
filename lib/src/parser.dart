import './grammar.dart' show grammar;

toIntIfInt(v) {
  return v != null ? int.tryParse(v) != null ? int.parse(v) : v : null;
}

attachProperties(match, location, names, rawName) {
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

parseReg(obj, location, content) {
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

parse(sdp) {
  var session = {};
  var medias = [];

  var location =
      session; // points at where properties go under (one of the above)

  // parse lines we understand
  sdp.split(new RegExp(r"\r|\r\n|\n")).forEach((l) {
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
        if (RegExp(obj['reg']).hasMatch(content)) {
          return parseReg(obj, location, content);
        }
      }
    }
  });
  session['media'] = medias; // link it up
  return session;
}

paramReducer(acc, expr) {
  var s = expr.split(new RegExp(r'/=(.+)/'), 2);
  if (s.length == 2) {
    acc[s[0]] = toIntIfInt(s[1]);
  } else if (s.length == 1 && expr.length > 1) {
    acc[s[0]] = null;
  }
  return acc;
}

parseParams(str) {
  return str.split(new RegExp(r'/;\s?/')).reduce(paramReducer, {});
}

parsePayloads(str) {
  return str.split(' ').map();
}

parseRemoteCandidates(str) {
  var candidates = [];
  var parts = str.split(' ').map(toIntIfInt);
  for (var i = 0; i < parts.length; i += 3) {
    candidates
        .add({'component': parts[i], 'ip': parts[i + 1], 'port': parts[i + 2]});
  }
  return candidates;
}

parseImageAttributes(str) {
  return str.split(' ').map((item) {
    return item
        .substring(1, item.length - 1)
        .split(',')
        .reduce(paramReducer, {});
  });
}

parseSimulcastStreamList(str) {
  return str.split(';').map((stream) {
    return stream.split(',').map((format) {
      var scid, paused = false;

      if (format[0] != '~') {
        scid = toIntIfInt(format);
      } else {
        scid = toIntIfInt(format.substring(1, format.length));
        paused = true;
      }
      return {scid: scid, paused: paused};
    });
  });
}
