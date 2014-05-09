import "dart:html";
import "GameEngine.dart";
import "SubLevel.dart";
import "cards.dart";

class LevelComplete {
    static GameEngine engine;

    static int targetLevel;
    static SubLevel last;

    static void show(GameEngine e) {
        engine = e;
        var table = querySelector(".sublevel-table");
        var frw = querySelector("#finished-level-box");
        frw.classes.remove("hidden");
        frw.query(".level-rating").classes.add("fs-" + e.level.getRating().toString());
        table.classes.remove("hidden");
        for (SubLevel sl in e.level.subLevels) {
            Element el = new Element.html(querySelector(".sl-template").innerHtml);
            el.query(".sl-name").text = sl.name;
            el.query(".sl-rating").classes.add("sl-" + sl.rating.toString());
            el.dataset['level'] = sl.index.toString();
            el.removeEventListener("click", onItemClick);
            el.addEventListener("click", onItemClick);
            table.append(el);
        }
    }

    static void hide() {
        var frw = querySelector("#finished-level-box");
        frw.classes.add("hidden");
        var table = querySelector(".sublevel-table");
        table.innerHtml = "";
    }

    static void onItemClick(event) {
        DivElement el = (event.currentTarget as DivElement);
        targetLevel = int.parse(el.dataset['level']);
        if(targetLevel== engine.level.currentSubLevel) {
            engine.restartLevel();
        } else {
            last = engine.level.current;
            engine.level.previous();
            engine.level.current.levelApplied = onLevelApplied;
        }

        engine.isPaused = false;
        hide();
    }

    static void onLevelApplied() {
        last.frames.clear();
        print("target level:" + targetLevel.toString());
        print("current level: "+ engine.level.currentSubLevel.toString());
      if(targetLevel != engine.level.currentSubLevel) {
          engine.level.previous();
          engine.level.current.levelApplied = onLevelApplied;
      } else {
          engine.level.current.levelApplied = null;
          applyPhysicsLabelToButton();
      }
    }
}
