import "dart:html";
import "GameEngine.dart";
import "SubLevel.dart";

class LevelComplete {
    LevelComplete(GameEngine e) {
        var table = querySelector(".sublevel-table");
        var frw = querySelector("#finished-level-box");
        frw.classes.remove("hidden");
        frw.query(".level-rating").classes.add("fs-"+e.level.getRating().toString());
        table.classes.remove("hidden");
        for(SubLevel sl in e.level.subLevels) {
            Element el = new Element.html(querySelector(".sl-template").innerHtml);
            el.query(".sl-name").text = sl.name;
            el.query(".sl-rating").classes.add("sl-"+sl.rating.toString());
            table.append(el);
        }
    }
}
