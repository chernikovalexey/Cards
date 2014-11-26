import 'dart:html';
import 'SubLevel.dart';
import 'package:box2d/box2d_browser.dart';
import 'dart:convert';
import 'EnergySprite.dart';
import 'Bobbin.dart';
import 'GameEngine.dart';
import 'cards.dart';

class LevelSerializer {
    static double roundDouble(double n) {
        return (n * 1000.0).round() / 1000.0;
    }

    static String toJSON(List<Body> cards, List<List> frames, bool physicsEnabled, bool completed) {
        Map map = new Map();
        map['completed'] = completed;
        map['physics_enabled'] = physicsEnabled;
        map['cards'] = new List<Map>();
        map['frames'] = new List();

        for (Body body in cards) {
            if (!(body.userData as EnergySprite).isHint) {
                (map['cards'] as List).add({
                    'x': roundDouble(body.position.x), 'y': roundDouble(body.position.y), 'angle': roundDouble(body.angle), 'static': (body.userData as EnergySprite).isStatic, 'energy': roundDouble((body.userData as EnergySprite).energy)
                });
            }
        }

        if (!cards.isEmpty) {
            for (int i = 0, len = frames.length; i < len; ++i) {
                map['frames'].add(new List());
                for (var t in frames[i]) {
                    map['frames'][i].add({
                        'x': roundDouble(t.pos.x), 'y': roundDouble(t.pos.y), 'angle': roundDouble(t.angle)
                    });
                }
            }
        }

        return JSON.encode(map);
    }

    static bool fromJSON(String json, GameEngine e, SubLevel subLevel) {
        Map state = JSON.decode(json);

        for (Map card in state['cards']) {
            Body b = e.addCard(card['x'].toDouble(), card['y'].toDouble(), card['angle'].toDouble(), card['static'], subLevel);
            if (subLevel != null) b.type = BodyType.STATIC;

            (b.userData as EnergySprite).energy = card['energy'].toDouble();
        }

        applyPhysicsLabelToButton();

        List frames = new List();
        if (!state['cards'].isEmpty) {
            for (int i = 0, len = state['frames'].length; i < len; ++i) {
                frames.add(new List());
                for (Map t in state['frames'][i]) {
                    frames[i].add(new BTransform(new Vector2(t['x'].toDouble(), t['y'].toDouble()), t['angle'].toDouble()));
                }
            }
        }

        if (subLevel != null) {
            subLevel.frames = frames;
            subLevel.enable(false);
        } else {
            e.bobbin.list = frames;
        }

        if (subLevel != null) subLevel.loadRating();

        return state['completed'];
    }
}
