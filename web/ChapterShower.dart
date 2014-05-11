import "dart:html";
import 'cards.dart';
import 'Scroll.dart';
import 'dart:js';

class ChapterShower {
  static void show(List chapters) {
    querySelector("#chapter-es").innerHtml = "";

    int id = 0;
    for (Map chapter in chapters) {
      querySelector("#chapter-es").appendHtml(chapterItem(chapter, ++id));
    }
    
    var bar = Scroll.setup('chapter-vs', 'chapter-es', 'chapter-scrollbar');
    context['dw_Scrollbar_Co'].callMethod('addEvent', [bar, 'on_scroll', (var x, var y) {
      //print();
      querySelector("#chapter-blur-g").style.transform = "translatey(" + (y + 76).toString() + "px)";
    }]);
    
    context.callMethod('html2canvas', [querySelector('.chapter-list'), new JsObject.jsify({
      'onrendered': (CanvasElement canvas) {
        canvas.id = "chapter-blur-g";
        querySelector(".chapter-blurry-bar").append(canvas);
        context.callMethod('stackBlurCanvasRGB', ['chapter-blur-g', 0, 0, canvas.width, canvas.height, 254]);
        CanvasRenderingContext2D g = canvas.getContext('2d');
        g.fillStyle = 'rgba(0, 0, 0, 0.5)';
        g.fillRect(0, 0, canvas.width, canvas.height);
      }
    })]);

    querySelectorAll(".chapter").forEach((DivElement e) {
      e.addEventListener("click", (event) {
        if (!e.classes.contains("chapter-locked")) {
          int chapter = int.parse(e.dataset["id"]);
          manager.removeState(engine); // ???
          manager.addState(engine, {
            'chapter': chapter
          });
          updateCanvasPositionAndDimension();

          querySelector("#chapter-selection").classes.add("hidden");
          querySelector(".buttons").classes.remove("hidden");
          querySelector(".selectors").classes.remove("hidden");
        } else {
          print("Man, it's still locked, ok?");
        }
      }, false);
    });
    
    querySelector(".go-to-menu-button").addEventListener("click", (event) {
      fadeBoxOut(querySelector("#chapter-selection"), 125, () {
        showMainMenu();
      });
    }, false);
  }

  static String chapterItem(Map chapter, int id) {
    DivElement el = querySelector(".chapter-template") as DivElement;
    el.querySelector(".chapter").dataset["id"] = id.toString();
    el.querySelector(".chapter-title").innerHtml = chapter["name"];

    
    int totalStars = int.parse(window.localStorage["total_stars"]);
    bool unlocked = totalStars >= chapter["unlock_stars"];

    if (!unlocked) {
      //el.querySelector(".unlock-stars").innerHtml = (chapter["unlock_stars"] -
          //totalStars).toString() + " stars left to unlock";
      el.querySelector(".chapter").classes.add("chapter-locked");
    } else {
      //el.querySelector(".unlock-stars").innerHtml = "";
      el.querySelector(".chapter").classes.remove("chapter-locked");
      
      double w = 240 * 12/49;
      el.querySelector(".current-bar").style.width = w.toString() + "px";
    }

    return el.innerHtml;
  }
}
