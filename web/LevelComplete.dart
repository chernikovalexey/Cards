import "dart:html";
import "GameEngine.dart";
import "SubLevel.dart";

class LevelComplete {
    static GameEngine engine;

    static int n;

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
        n = engine.level.subLevels.length - int.parse(el.dataset['level']);
        print("Delta level:" + n.toString());
        hide();
        if (n > 0) {
            n--;
            onLevelApplied();
            }
        else {
            engine.restartLevel();
        }


        engine.isPaused = false;
    }

    static void onLevelApplied() {
        engine.level.previous();
        if(n>0) {
            engine.level.current.levelApplied = onLevelApplied;
        }
    }
}
