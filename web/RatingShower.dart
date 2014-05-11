import "dart:html";
import "GameEngine.dart";
import "LevelComplete.dart";
import "SubLevel.dart";
import "Level.dart";
import "Input.dart";
import "cards.dart";
import "Scroll.dart";
import 'package:animation/animation.dart';
import 'dart:async';

class RatingShower {
  static const int FADE_TIME = 450;

  static GameEngine e;
  static bool wasJustPaused = false;

  static bool pauseState = false;

  static void nextLevel(event) {
    hide();
    e.nextLevel();
    e.isPaused = false;
  }

  static void restartLevel(event) {
    hide();
    e.isPaused = false;
    e.restartLevel();
  }

  static String tapeItem(Map l, int index, int current) {
    DivElement el = (querySelector(".tape-item-template") as DivElement);
    //el.querySelector(".tape-rating").innerHtml = l.rating.toString();
    el.querySelector(".tape-name").innerHtml = l["name"];
    DivElement tr = el.querySelector(".tape-rating") as DivElement;
    DivElement ti = el.querySelector(".tape-item") as DivElement;
    ti.dataset['level'] = (index + 1).toString();

    if (index < e.level.subLevels.length) {
      tr.classes.add("tr-" + e.level.subLevels[index].rating.toString());
    } else {
      tr.classes.add("tr-0");
      ti.classes.add("locked");
    }

    if (index == current) ti.classes.add("tape-current-item");

    String result = el.innerHtml;

    if (ti.classes.contains("locked")) ti.classes.remove("locked");

    if (index == current) ti.classes.remove("tape-current-item");

    tr.classes.clear();
    tr.classes.add("tape-rating");

    return result;
  }

  static void show(GameEngine engine, int rating) {
    e = engine;
    e.isPaused = true;
    querySelector(".chapter-controls").classes.add("hidden");

    querySelector(".game-box").classes.add("paused");
    querySelector(".level-name").style.display = "none";

    DivElement box = (querySelector("#rating-box") as DivElement);
    box.classes.remove("hidden");

    animate(box, properties: {
      'opacity': 1.0
    }, duration: 450, easing: Easing.CUBIC_EASY_IN);

    new Timer(new Duration(milliseconds: FADE_TIME), () {
      querySelector("#graphics").classes.add("blurred");
      querySelector(".buttons").classes.add("blurred");
      querySelector(".selectors").classes.add("blurred");
    });

    Input.keyDown = (KeyboardEvent e) {
      if (e.keyCode == Input.keys['esc'].code) {
        Input.keys['esc'].clicked = false;
        Input.keys['esc'].down = false;
        hide();
        Input.keyDown = null;
      }
    };

    var classes = (querySelector(".level-rating") as DivElement).classes;

    for (int i = 0; i < 4; i++) if (classes.contains("s-" + i.toString()))
        classes.remove("s-" + i.toString());
    classes.add("s-" + rating.toString());


    (querySelector(".s-level-name") as DivElement).innerHtml =
        e.level.current.name;
    (querySelector(".chapter-level") as DivElement).innerHtml =
        e.level.current.index.toString() + " of " + e.level.levels.length.toString();


    (querySelector("#next-level") as ButtonElement).focus();
    (querySelector("#next-level") as ButtonElement).removeEventListener("click",
        nextLevel);

    (querySelector("#next-level") as ButtonElement).addEventListener("click",
        nextLevel);

    (querySelector("#restart-level") as ButtonElement).removeEventListener(
        "click", restartLevel);
    (querySelector("#restart-level") as ButtonElement).addEventListener("click",
        restartLevel);

    (querySelector("#tape-es") as DivElement).innerHtml = "";
    String s = "";
    for (int i = 0; i < e.level.levels.length; i++) {
      s += tapeItem(e.level.levels[i], i, e.level.currentSubLevel - 1);
    }

    final NodeValidatorBuilder _htmlValidator = new NodeValidatorBuilder.common(
        )..allowElement('div', attributes: ['data-target', 'data-level']);


    (querySelector("#tape-es") as DivElement).setInnerHtml(s, validator:
        _htmlValidator);

    for (DivElement e in querySelectorAll(".tape-item")) {
      if (!e.classes.contains('locked')) {
        e.removeEventListener("click", onTypeItemClick);
        e.addEventListener("click", onTypeItemClick);
      }
    }

    querySelector("#clear-level").addEventListener('click', (e) {
      engine.clear();
      hide();
    });

    if (pauseState) {
      querySelector(".level-controls").classes.add('hidden');
      querySelector(".pause-controls").classes.remove('hidden');
      querySelector(".pause-title").classes.remove('hidden');
      querySelector(".chapter-rating-wrap").classes.add("hidden");
      querySelector(".chapter-controls").classes.add("hidden");
      querySelector("#pm-menu").removeEventListener("click", mainMenu);
      querySelector("#pm-menu").addEventListener("click", mainMenu);
    } else {
      querySelector(".level-controls").classes.remove('hidden');
      querySelector(".pause-controls").classes.add('hidden');
      querySelector(".level-rating").classes.remove('hidden');
      querySelector(".pause-title").classes.add('hidden');
    }

    Scroll.setup('tape-vs', 'tape-es', 'tape-scrollbar', 'h');

    if (!e.level.hasNext() && !pauseState) {
      chapterComplete();
    }
  }

  static void pause(GameEngine e) {
    pauseState = true;
    show(e, 0);
    pauseState = false;
  }

  static void chapterComplete() {
    querySelector(".rating-wrap").classes.add("hidden");
    querySelector(".chapter-rating-wrap").classes.remove("hidden");
    querySelector(".pause-controls").classes.add("hidden");
    querySelector(".level-controls").classes.add("hidden");
    querySelector(".chapter-controls").classes.remove("hidden");
    int totalStars = 0;
    for (SubLevel l in e.level.subLevels) {
      totalStars += l.rating;
    }
    querySelector(".chapter-raring").innerHtml = totalStars.toString();
    // querySelector(".main-menu").removeEventListener('click', mainMenu);
    querySelector("#cm-menu").addEventListener('click', mainMenu);

    window.localStorage.remove("last");
  }

  static void mainMenu(Event e) {
    hide();
    showMainMenu();
  }

  static void onTypeItemClick(Event evt) {
    hide();
    e.isPaused = false;
    Level.navigateToLevel(int.parse((evt.currentTarget as
        DivElement).dataset['level']), e);
  }

  static void hide() {
    e.isPaused = false;
    wasJustPaused = true;

    fadeBoxOut(querySelector("#rating-box"), 100, () {
      querySelector(".level-name").style.display = "block";

      querySelector(".game-box").classes.remove("paused");
      querySelector("#graphics").classes.remove("blurred");
      querySelector(".buttons").classes.remove("blurred");
      querySelector(".selectors").classes.remove("blurred");
    });
  }
}
