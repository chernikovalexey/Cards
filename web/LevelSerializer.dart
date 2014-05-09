import 'dart:html';
import 'SubLevel.dart';
import 'package:box2d/box2d_browser.dart';
import 'dart:convert';
import 'EnergySprite.dart';
import 'Bobbin.dart';
import 'GameEngine.dart';
import 'cards.dart';

class LevelSerializer {
  static String toJSON(List<Body> cards, List<List> frames, bool physicsEnabled)
      {
    Map map = new Map();
    map['physics_enabled'] = physicsEnabled;
    map['cards'] = new List<Map>();
    map['frames'] = new List();

    for (Body body in cards) {
      (map['cards'] as List).add({
        'x': body.position.x,
        'y': body.position.y,
        'angle': body.angle,
        'static': (body.userData as EnergySprite).isStatic,
        'energy': (body.userData as EnergySprite).energy
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

  static void fromJSON(String json, GameEngine e, SubLevel subLevel) {
    Map state = JSON.decode(json);

    for (Map card in state['cards']) {
      Body b = e.addCard(card['x'].toDouble(), card['y'].toDouble(),
          card['angle'].toDouble(), card['static'], subLevel==null?null:subLevel);

      (b.userData as EnergySprite).energy = card['energy'].toDouble();
    }

    if (state['physics_enabled']) {
      applyRewindLabelToButton();
    } else {
      applyPhysicsLabelToButton();
    }

    List frames = new List();
    for (int i = 0, len = state['frames'].length; i < len; ++i) {
      frames.add(new List());
      for (Map t in state['frames'][i]) {
        frames[i].add(new BTransform(new Vector2(t['x'].toDouble(),
            t['y'].toDouble()), t['angle'].toDouble()));
      }
    }

    if (subLevel != null) {
      subLevel.frames = frames;
      subLevel.enable(false);
    } else {
      e.bobbin.list = frames;
    }
  }
}
