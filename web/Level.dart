import "dart:html";
import "dart:async";
import 'dart:convert';
import 'GameEngine.dart';
import 'package:box2d/box2d_browser.dart';
import "Sprite.dart";
import "SubLevel.dart";
import 'cards.dart';

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
            if(current!=null) current.enable(false);
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
            saveCurrentLevel();
            updateBlockButtons(engine);
        }
        print("Current sub level: " + (currentSubLevel).toString());
    }

    void previous() {
        if(hasPrevious()) {
            --currentSubLevel;
            current.saveState();
            current = subLevels[currentSubLevel - 1];
            current.apply();
            saveCurrentLevel();
        }
        print("Current sub level: " + (currentSubLevel).toString());
    }
    
    void saveCurrentLevel() {
      showLevelName(subLevels[currentSubLevel - 1].name);
      window.localStorage['last_level'] = currentSubLevel.toString();
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

    int getRating() {
        int min = 3;
        for(SubLevel sl in subLevels) {
            if(sl.rating<min) min = sl.rating;
        }

        return min;
    }
}
