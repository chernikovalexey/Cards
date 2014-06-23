import "dart:html";
import "dart:async";
import 'dart:convert';
import 'GameEngine.dart';
import 'package:box2d/box2d_browser.dart';
import "Sprite.dart";
import "SubLevel.dart";
import 'cards.dart';
import 'LevelSerializer.dart';
import 'GameWizard.dart';
import 'WebApi.dart';

class Level {
  GameEngine engine;
  SubLevel current;
  List<SubLevel> subLevels = new List();
  int currentSubLevel;
  List levels;

  int chapter;

  Level(Function ready, int chapter, GameEngine engine, bool _continue) {
    preload(ready, chapter, _continue);

    this.chapter = chapter;
    this.engine = engine;
  }

  // real amount minus one
  int findLastEmptyLevel(int ch) {
    int index = 0;
    while (window.localStorage.containsKey("level_" + ch.toString() + "_" +
        (++index).toString())) {}
    return index - 1 >= levels.length ? levels.length - 1 : index - 1;
  }

  void preload(Function ready, int chapter, bool _continue) {
    Storage storage = window.localStorage;

    HttpRequest.getString("levels/chapter_" + chapter.toString() + ".json"
        ).then((String str) {
      levels = JSON.decode(str)["levels"];

      Map last;
      if (_continue || (storage.containsKey("last") && (last = JSON.decode(storage["last"]
          ))["chapter"] == chapter)) {
        last = JSON.decode(storage["last"]);
        currentSubLevel = last["level"];
        loadCurrent();
      } else {
        currentSubLevel = findLastEmptyLevel(chapter);
        next();
      }

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
      if (current != null) {
        current.enable(false);
      }
      ++currentSubLevel;
      loadCurrent();
    }
  }

  void loadCurrent() {
    if (currentSubLevel > subLevels.length) {
      for (int i = subLevels.length; i < currentSubLevel; ++i) {
        subLevels.add(load(i + 1));
      }

      WebApi.levelStart(chapter ,currentSubLevel);
    } else {
      current = subLevels[currentSubLevel - 1];
      current.online(true);
      current.apply();
    }

    GameWizard.manage(chapter, current.index);
    handleLevelChange();
    updateBlockButtons(engine);
  }

  void previous() {
    if (hasPrevious()) {
      --currentSubLevel;
      current.saveState();
      current.online(false);
      current = subLevels[currentSubLevel - 1];
      current.apply();
      handleLevelChange();
    }
  }

  void handleLevelChange() {
    showLevelName(subLevels[currentSubLevel - 1].name);

    window.localStorage["last"] = JSON.encode({
      'chapter': chapter,
      'level': currentSubLevel
    });
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
    } else if(target < eng.level.currentSubLevel) {
      last = eng.level.current;
      eng.frontRewind = false;
      eng.level.previous();
      eng.level.current.levelApplied = onLevelApplied;
    } else {
      eng.frontRewind = true;
      if(!eng.physicsEnabled) {
          applyRewindLabelToButton();
          eng.frontRewindLevelComplete = onFrontRewindLevelComplete;
          eng.frontRewindLevelFailed = onFrontRewindLevelFailed;
      }
      eng.level.next();
    }
  }

  static void onFrontRewindLevelComplete() {
      print("onFrontRewindLevelComplete");
      print("target: "+targetLevel.toString()+" current: "+ eng.level.currentSubLevel.toString());
    if(targetLevel != eng.level.currentSubLevel) {
        eng.level.next();
        applyRewindLabelToButton();
    } else {
      eng.level.current.online(true);
    }
  }

  static void onFrontRewindLevelFailed() {

  }

  static void onLevelApplied() {
    last.frames.clear();
    if (targetLevel < eng.level.currentSubLevel) {
      eng.level.previous();
      eng.level.current.levelApplied = onLevelApplied;
    } else if(targetLevel == eng.level.currentSubLevel) {
      eng.level.current.levelApplied = null;
      applyPhysicsLabelToButton();
    }
  }
}
