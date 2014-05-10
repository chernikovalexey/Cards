import "dart:html";
import "dart:async";
import 'dart:convert';
import 'GameEngine.dart';
import 'package:box2d/box2d_browser.dart';
import "Sprite.dart";
import "SubLevel.dart";
import 'cards.dart';
import 'LevelSerializer.dart';

class Level {
  GameEngine engine;
  SubLevel current;
  List<SubLevel> subLevels = new List();
  int currentSubLevel;
  List levels;

  int chapter;

  Level(Function ready, int chapter, GameEngine engine) {
    preload(ready, chapter);

    this.chapter = chapter;
    this.engine = engine;
  }

  void preload(Function ready, int chapter) {
    Storage storage = window.localStorage;

    HttpRequest.getString("levels/chapter_" + chapter.toString() + ".json"
        ).then((String str) {
      levels = JSON.decode(str)["levels"];

      /*if (storage.containsKey("last_level")) {
        currentSubLevel = int.parse(storage['last_level']);
        loadCurrent();
      } else {*/
      currentSubLevel = 0;
      next();
      //}

      for (int i = 0; i < currentSubLevel; ++i) {
        String level = 'level_' + chapter.toString() + '_' + (i + 1).toString();

        if (storage.containsKey(level)) {
          LevelSerializer.fromJSON(storage[level], engine, i + 1 !=
              currentSubLevel ? subLevels[i] : null);
          if (i + 1 != currentSubLevel) {
            subLevels[i].complete();
          }
        }
      }

      ready();
    });
  }

  void next() {
    if (hasNext()) {
      if (current != null) current.enable(false);
      ++currentSubLevel;
      loadCurrent();
    }
    print("Current sub level: " + (currentSubLevel).toString());
  }

  void loadCurrent() {
    if (currentSubLevel > subLevels.length) {
      print("load further levels ...");
      for (int i = subLevels.length; i < currentSubLevel; ++i) {
        subLevels.add(load(i + 1));
      }
    } else {
      current = subLevels[currentSubLevel - 1];
      current.apply();
    }

    handleLevelChange();
    updateBlockButtons(engine);
  }

  void previous() {
    if (hasPrevious()) {
      --currentSubLevel;
      current.saveState();
      current = subLevels[currentSubLevel - 1];
      current.apply();
      handleLevelChange();
    }
    print("Current sub level: " + (currentSubLevel).toString());
  }

  void handleLevelChange() {
    showLevelName(subLevels[currentSubLevel - 1].name);

    if (hasNext()) {
      window.localStorage["last"] = JSON.encode({
        'chapter': chapter,
        'level': currentSubLevel
      });
    } else {
      window.localStorage.remove("last");
    }
  }

  bool hasNext() {
    return levels.length >= currentSubLevel + 1;
  }

  bool hasPrevious() {
    return currentSubLevel > 1;
  }

  SubLevel load(int level) {
    current = new SubLevel(engine, levels[level - 1], level);
    return current;
  }

  int getRating() {
    int min = 3;
    for (SubLevel sl in subLevels) {
      if (sl.rating < min) min = sl.rating;
    }

    return min;
  }

  static int targetLevel;
  static SubLevel last;
  static GameEngine eng;

  static void navigateToLevel(int target, GameEngine _eng) {
    eng = _eng;
    targetLevel = target;
    if (targetLevel == eng.level.currentSubLevel) {
      eng.restartLevel();
    } else {
      last = eng.level.current;
      eng.level.previous();
      eng.level.current.levelApplied = onLevelApplied;
    }
  }

  static void onLevelApplied() {
    last.frames.clear();
    if (targetLevel != eng.level.currentSubLevel) {
      eng.level.previous();
      eng.level.current.levelApplied = onLevelApplied;
    } else {
      eng.level.current.levelApplied = null;
      applyPhysicsLabelToButton();
    }
  }
}
