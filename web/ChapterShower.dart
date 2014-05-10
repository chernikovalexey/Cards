import "dart:html";
import 'cards.dart';

class ChapterShower {
  static void show(List chapters) {
    querySelector(".chapter-list").innerHtml = "";
    
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
        querySelector(".buttons").classes.remove("hidden");
        querySelector(".selectors").classes.remove("hidden");
      }, false);
    });
  }

  static String chapterItem(Map chapter, int id) {
    DivElement el = querySelector(".chapter-template") as DivElement;
    el.querySelector(".chapter").dataset["id"] = id.toString();
    el.querySelector(".chapter-title").innerHtml = chapter["name"];
    
    int totalStars = int.parse(window.localStorage["total_stars"]);
    bool unlocked = totalStars >= chapter["unlock_stars"];
    
    if(!unlocked) {
      el.querySelector(".unlock-stars").innerHtml =
              (chapter["unlock_stars"] - totalStars).toString() + " stars left to unlock";
      el.querySelector(".chapter-thumbnail").classes.add("chapter-locked");
    } else {
      el.querySelector(".unlock-stars").innerHtml = "0";
      el.querySelector(".chapter-thumbnail").classes.remove("chapter-locked");
    }
    
    return el.innerHtml;
  }
}
