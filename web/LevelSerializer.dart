import 'dart:html';
import 'SubLevel.dart';
import 'package:box2d/box2d_browser.dart';
import 'dart:convert';
import 'EnergySprite.dart';
import 'Bobbin.dart';
import 'GameEngine.dart';

class LevelSerializer {
  static String toJSON(List<Body> cards, List<List> frames, bool finished) {
    Map map = new Map();
    map['finished'] = finished;
    map['cards'] = new List<Map>();
    map['frames'] = new List();

    for (Body body in cards) {
      (map['cards'] as List).add({
        'x': body.position.x,
        'y': body.position.y,
        'angle': body.angle,
        'static': (body.userData as EnergySprite).isStatic
      });
    }

    for (int i = 0, len = frames.length; i < len; ++i) {
      map['frames'].add(new List());
      for (var t in frames[i]) {
        map['frames'][i].add({
          'x': t.pos.x,
          'y': t.pos.y,
          'angle': t.angle
        });
      }
    }

    return JSON.encode(map);
  }

  static void fromJSON(String json, GameEngine e) {
    Map state = JSON.decode(json);

    for (Map card in state['cards']) {
      e.addCard(card['x'].toDouble(), card['y'].toDouble(),
          card['angle'].toDouble(), card['static'] == "true");
    }

    if (state['finished'] == "true") {
      e.togglePhysics(true);
    }

    /*List frames = new List();
    for (List frame in state['frames']) {
      frames.add(new List());
      for (Map t in frame) {
        frames.add(new BTransform(new Vector2(t['x'].toDouble(), t['y'].toDouble(
            )), t['angle'].toDouble()));
      }
    }

    e.bobbin.list = frames;*/
  }
}
