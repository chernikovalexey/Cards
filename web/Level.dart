import "dart:html";
import "dart:async";
import 'dart:convert';
import 'GameEngine.dart';
import 'package:box2d/box2d_browser.dart';
import "Sprite.dart";
import "SubLevel.dart";

class Level {
    GameEngine engine;
    SubLevel current;
    List<SubLevel> subLevels = new List();
    int currentSubLevel;
    List levels;

    Level(Function ready, GameEngine engine) {
        preload(ready);
        this.engine = engine;
    }

    void preload(Function ready) {
        HttpRequest.getString("levels.json").then((String str) {
            levels = JSON.decode(str)["levels"];
            currentSubLevel = 0;
            next();
            ready();
        });
    }

    void next() {
        if (hasNext()) {
            print("Ready to load the next level: " + (currentSubLevel + 1).toString());
            ++currentSubLevel;
            if(currentSubLevel > subLevels.length) {
                load(currentSubLevel);
                subLevels.add(current);
            }
            else
            {
                current = subLevels[currentSubLevel - 1];
                current.apply();
            }
        }
    }

    void previous() {
        if(hasPrevious()) {
            --currentSubLevel;
            current = subLevels[currentSubLevel];
            current.apply();
        }
    }

    bool hasNext() {
        return levels.length >= currentSubLevel + 1;
    }

    bool hasPrevious() {
        return currentSubLevel > 1;
    }

    SubLevel load(int level) {
        current = new SubLevel(engine,levels[currentSubLevel - 1], currentSubLevel);
        return current;
    }
}
