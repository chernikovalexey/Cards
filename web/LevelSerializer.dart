import 'dart:html';
import 'SubLevel.dart';
import 'package:box2d/box2d_browser.dart';
import 'dart:convert';
import 'EnergySprite.dart';
import 'Bobbin.dart';
import 'GameEngine.dart';
import 'cards.dart';
import 'Sprite.dart';

class LevelSerializer {
    static double roundDouble(double n) {
        return (n * 1000.0).round() / 1000.0;
    }

    static String toJSON(List<Body> cards, List<List> frames, List<Body> _do, List<List> doFrames, bool physicsEnabled, bool completed) {
        Map map = new Map();
        map['completed'] = completed;
        map['physics_enabled'] = physicsEnabled;
        map['cards'] = new List<Map>();
        map['frames'] = new List();
        map['do'] = new List<Map>();
        map['do_frames'] = new List();

        for (Body body in cards) {
            if (!(body.userData as EnergySprite).isHint) {
                map['cards'].add({
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

        for (Body body in _do) {
            if (!body.userData.isStatic) {
                map['do'].add({
                    'id': (body.userData as Sprite).id, 'x': roundDouble(body.position.x), 'y': roundDouble(body.position.y), 'angle': roundDouble(body.angle)
                });
            }
        }

        if (!_do.isEmpty) {
            for (int i = 0, len = doFrames.length; i < len; ++i) {
                map['do_frames'].add(new List());
                for (var t in doFrames[i]) {
                    map['do_frames'][i].add({
                        'x': roundDouble(t.pos.x), 'y': roundDouble(t.pos.y), 'angle': roundDouble(t.angle)
                    });
                }
            }
        }

        return JSON.encode(map);
    }

    static bool fromJSON(String json, GameEngine e, SubLevel subLevel, [bool further = false]) {
        Map state = JSON.decode(json);

        for (Map card in state['cards']) {
            Body b = e.addCard(card['x'].toDouble(), card['y'].toDouble(), card['angle'].toDouble(), card['static'], subLevel);
            if (subLevel != null) b.type = BodyType.STATIC;

            (b.userData as EnergySprite).energy = card['energy'].toDouble();
        }

        List frames = new List();
        if (!state['cards'].isEmpty) {
            for (int i = 0, len = state['frames'].length; i < len; ++i) {
                frames.add(new List());
                for (Map t in state['frames'][i]) {
                    frames[i].add(new BTransform(new Vector2(t['x'].toDouble(), t['y'].toDouble()), t['angle'].toDouble()));
                }
            }
        }

        List<Body> obstacles = subLevel != null ? subLevel.obstacles : e.level.current.obstacles;

        for (Map t in state['do']) {
            int id = t['id'].toInt();
            for (Body obstacle in obstacles) {
                if ((obstacle.userData as Sprite).id == id) {
                    obstacle.setTransform(new Vector2(t['x'].toDouble(), t['y'].toDouble()), t['angle'].toDouble());
                }
            }
        }

        List doFrames = new List();
        if (!state['do'].isEmpty) {
            for (int i = 0, len = state['do_frames'].length; i < len; ++i) {
                doFrames.add(new List());
                for (Map t in state['do_frames'][i]) {
                    doFrames[i].add(new BTransform(new Vector2(t['x'].toDouble(), t['y'].toDouble()), t['angle'].toDouble()));
                }
            }
        }

        applyPhysicsLabelToButton();

        if (subLevel != null) {
            subLevel.frames = frames;
            subLevel.obstaclesFrames = doFrames;

            subLevel.enable(false);

            if (!further) {
                subLevel.loadRating();
            }
        } else {
            e.bobbin.list = frames;
            e.obstaclesBobbin.list = doFrames;
        }

        return state['completed'];
    }
}
