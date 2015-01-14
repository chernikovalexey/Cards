import 'dart:html';
import 'SubLevel.dart';
import 'package:box2d/box2d_browser.dart';
import 'dart:convert';
import 'EnergySprite.dart';
import 'Bobbin.dart';
import 'GameEngine.dart';
import 'cards.dart';
import 'Sprite.dart';
import 'Chapter.dart';

class LevelSerializer {
    static double roundDouble(double n) {
        return (n * 1000.0).round() / 1000.0;
    }

    static String toJSON(List<Body> cards, List<List> frames, List<Body> _do, List<List> doFrames, bool completed) {
        Map map = new Map();

        map['cd'] = completed;
        map['c'] = new List<Map>();
        map['f'] = new List();
        map['do'] = new List<Map>();
        map['df'] = new List();

        for (Body body in cards) {
            if (!(body.userData as EnergySprite).isHint) {
                map['c'].add({
                    'x': roundDouble(body.position.x), 'y': roundDouble(body.position.y), 'a': roundDouble(body.angle), 's': (body.userData as EnergySprite).isStatic, 'e': roundDouble((body.userData as EnergySprite).energy)
                });
            }
        }

        if (!cards.isEmpty) {
            for (int i = 0, len = frames.length; i < len; ++i) {
                map['f'].add(new List());
                for (var t in frames[i]) {
                    map['f'][i].add({
                        'x': roundDouble(t.pos.x), 'y': roundDouble(t.pos.y), 'a': roundDouble(t.angle)
                    });
                }
            }
        }

        for (Body body in _do) {
            if (!body.userData.isStatic) {
                map['do'].add({
                    'id': (body.userData as Sprite).id, 'x': roundDouble(body.position.x), 'y': roundDouble(body.position.y), 'a': roundDouble(body.angle)
                });
            }
        }

        if (!_do.isEmpty) {
            for (int i = 0, len = doFrames.length; i < len; ++i) {
                map['df'].add(new List());
                for (var t in doFrames[i]) {
                    map['df'][i].add({
                        'x': roundDouble(t.pos.x), 'y': roundDouble(t.pos.y), 'a': roundDouble(t.angle)
                    });
                }
            }
        }

        return JSON.encode(map);
    }

    static bool fromJSON(String json, GameEngine e, SubLevel subLevel, [bool further = false]) {
        Map state = JSON.decode(json);

        for (Map card in state['c']) {
            Body b = e.addCard(card['x'].toDouble(), card['y'].toDouble(), card['a'].toDouble(), card['s'], subLevel);
            if (subLevel != null) b.type = BodyType.STATIC;

            (b.userData as EnergySprite).energy = card['e'].toDouble();
        }

        List frames = new List();
        if (!state['c'].isEmpty) {
            for (int i = 0, len = state['f'].length; i < len; ++i) {
                frames.add(new List());
                for (Map t in state['f'][i]) {
                    frames[i].add(new BTransform(new Vector2(t['x'].toDouble(), t['y'].toDouble()), t['a'].toDouble()));
                }
            }
        }

        List<Body> obstacles = subLevel != null ? subLevel.obstacles : e.level.current.obstacles;

        for (Map t in state['do']) {
            int id = t['id'].toInt();
            for (Body obstacle in obstacles) {
                if ((obstacle.userData as Sprite).id == id) {
                    obstacle.setTransform(new Vector2(t['x'].toDouble(), t['y'].toDouble()), t['a'].toDouble());
                }
            }
        }

        List doFrames = new List();
        if (!state['do'].isEmpty) {
            for (int i = 0, len = state['df'].length; i < len; ++i) {
                doFrames.add(new List());
                for (Map t in state['df'][i]) {
                    doFrames[i].add(new BTransform(new Vector2(t['x'].toDouble(), t['y'].toDouble()), t['a'].toDouble()));
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

        return state['cd'];
    }

    // Shorter names
    // Indicator of completeness of a level

    static void syncVersions() {
        Storage storage = window.localStorage;

        Map last = null;
        if (storage.containsKey('last')) last = JSON.decode(storage['last']);

        for (int chapter = 1; chapter <= Chapter.chapters.length; ++chapter) {
            for (int level = 1; level <= 12; ++level) {
                String levelName = 'level_' + chapter.toString() + '_' + level.toString();

                if (!storage.containsKey(levelName)) {
                    break;
                }

                Map json = JSON.decode(storage[levelName]);
                Map nj = new Map();

                // Already updated
                if (json.containsKey('cd') && json.containsKey('c')) {
                    continue;
                }

                bool hasFullCards = false;

                nj['c'] = new List<Map>();
                for (Map card in json['cards']) {
                    if (card['energy'].toDouble() > 0.5) {
                        hasFullCards = true;
                    }

                    nj['c'].add({
                        'x': card['x'], 'y': card['y'], 'a': card['angle'], 's': card['static'], 'e': card['energy']
                    });
                }

                if (json.containsKey('completed')) {
                    nj['cd'] = json['completed'];
                } else {
                    nj['cd'] = hasFullCards;

                    if (!hasFullCards && last['chapter'] == chapter && last['level'] != level && level > 1) {
                        last['level'] = level;
                    }
                }

                nj['f'] = new List();
                for (int i = 0, len = json['frames'].length; i < len; ++i) {
                    nj['f'].add(new List());
                    for (Map t in json['frames'][i]) {
                        nj['f'][i].add({
                            'x': t['x'], 'y': t['y'], 'a': t['angle']
                        });
                    }
                }

                nj['do'] = new List<Map>();
                nj['df'] = new List();

                storage[levelName] = JSON.encode(nj);
            }
        }

        if (last != null) storage['last'] = JSON.encode(last);
    }
}
