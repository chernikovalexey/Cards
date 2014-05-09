import "dart:html";
import "GameEngine.dart";
import "SubLevel.dart";
import "cards.dart";
import "Level.dart";

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
        engine.isPaused = false;
        DivElement el = (event.currentTarget as DivElement);
        Level.navigateToLevel(int.parse(el.dataset['level']), engine);


        hide();
    }
}
