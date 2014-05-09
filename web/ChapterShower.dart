import "dart:html";
import 'cards.dart';

class ChapterShower {
  static void show(List chapters) {
    int id = 0;
    for (Map chapter in chapters) {
      querySelector(".chapter-list").appendHtml(chapterItem(chapter, ++id));
    }

    querySelectorAll(".chapter").forEach((DivElement e) {
      e.addEventListener("click", (event) {
        int chapter = int.parse(e.dataset["id"]);
        manager.addState(engine, {
          'chapter': chapter
        });
        updateCanvasPositionAndDimension();

        querySelector("#chapter-selection").classes.add("hidden");
      }, false);
    });
  }

  static String chapterItem(Map chapter, int id) {
    DivElement el = querySelector(".chapter-template") as DivElement;
    el.querySelector(".chapter").dataset["id"] = id.toString();
    el.querySelector(".chapter-title").innerHtml = chapter["name"];
    el.querySelector(".unlock-stars").innerHtml =
        chapter["unlock_stars"].toString() + " stars left to unlock";
    return el.innerHtml;
  }
}
