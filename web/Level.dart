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
            load(currentSubLevel);
        }
    }

    bool hasNext() {
        return levels.length >= currentSubLevel + 1;
    }

    void load(int level) {
        current = new SubLevel(engine,levels[currentSubLevel - 1], currentSubLevel);
        return current;
    }
}
