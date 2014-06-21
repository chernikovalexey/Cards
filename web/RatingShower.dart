import "dart:html";
import "GameEngine.dart";
import "SubLevel.dart";
import "Level.dart";
import "Input.dart";
import "cards.dart";
import "Scroll.dart";
import 'package:animation/animation.dart';
import 'dart:async';
import "StarManager.dart";
import 'GameWizard.dart';
import 'WebApi.dart';

class RatingShower {
  static const int FADE_TIME = 450;
  static int oldRating, newRating;

  static GameEngine e;
  static bool wasJustPaused = false;

  static bool pauseState = false;

  static void nextLevel(event) {
    WebApi.finishLevel(newRating);
    hide();
    StarManager.updateResult(e.level.chapter, newRating - oldRating);
    e.nextLevel();
    e.isPaused = false;
  }

  static void restartLevel(event) {
    hide();
    e.isPaused = false;
    e.restartLevel();
  }

  static String tapeItem(Map l, int chapter, int index, int current) {
    DivElement el = (querySelector(".tape-item-template") as DivElement);
    el.querySelector(".tape-name").innerHtml = l["name"];
    DivElement tr = el.querySelector(".tape-rating") as DivElement;
    DivElement ti = el.querySelector(".tape-item") as DivElement;

    for (int i = 1; i <= index + 1; ++i) {
      ti.classes.remove("ti-" + i.toString());
    }

    String levelIndex = (index + 1).toString();
    ti.dataset['level'] = levelIndex;
    ti.classes.add("ti-" + levelIndex);

    if (index >= e.level.subLevels.length) {
      ti.classes.add("locked");
    } else {
      tr.innerHtml = getStars(e.level.subLevels[index].rating);
    }

    if (index == current) ti.classes.add("tape-current-item");

    ti.id = chapter.toString() + "-" + levelIndex;
    
    String result = el.innerHtml;

    if (ti.classes.contains("locked")) ti.classes.remove("locked");

    if (index == current) ti.classes.remove("tape-current-item");

    tr.classes.clear();
    tr.classes.add("tape-rating");
    
    return result;
  }

  static String getStars(int stars) {
    DivElement tpl = querySelector(".star-template") as DivElement;
    int passed = 1;
    for (var star in tpl.querySelectorAll(".star")) {
      if (passed++ <= stars) star.classes.remove("extinct-star"); else
          star.classes.add("extinct-star");
    }
    return tpl.innerHtml;
  }

  static void show(GameEngine engine, int rating, [int oldR = 0]) {
    if (GameWizard.showing) {
      fadeBoxOut(GameWizard.progress, 175);
    }

    oldRating = oldR;
    newRating = rating;
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

    querySelector(".level-rating").innerHtml = getStars(rating);
    querySelector(".s-level-name").innerHtml = e.level.current.name;

    var chapterLevel = querySelector(".chapter-level");
    chapterLevel.querySelector(".finished-levels").innerHtml =
        e.level.current.index.toString();
    chapterLevel.querySelector(".all-levels").innerHtml =
        e.level.levels.length.toString();

    querySelector("#next-level").focus();
    querySelector("#next-level").removeEventListener("click",
        nextLevel);
    querySelector("#next-level").addEventListener("click",
        nextLevel);
    querySelector("#restart-level").removeEventListener(
        "click", restartLevel);
    querySelector("#restart-level").addEventListener("click",
        restartLevel);

    querySelector("#tape-es").innerHtml = "";
    String s = "";
    for (int i = 0; i < e.level.levels.length; i++) {
      s += tapeItem(e.level.levels[i], e.level.chapter, i, e.level.currentSubLevel - 1);
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

    DivElement nextTapeItem = querySelector(".ti-" + (e.level.currentSubLevel +
        1).toString());
    if (nextTapeItem != null) {
      nextTapeItem.classes.remove("locked");
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
      querySelector("#resume-game")
          ..removeEventListener("click", resume)
          ..addEventListener("click", resume, false);
      querySelector(".level-rating").classes.add('hidden');
    } else {
      querySelector(".level-controls").classes.remove('hidden');
      querySelector(".pause-controls").classes.add('hidden');
      querySelector(".level-rating").classes.remove('hidden');
      querySelector(".pause-title").classes.add('hidden');
    }

    querySelector("#tape-es").style.width = (e.level.levels.length * 172 +
        10).toString() + "px";
    Scroll.setup('tape-vs', 'tape-es', 'tape-scrollbar', 'h');
    Scroll.scrollTo('tape-vs', e.level.chapter.toString()+'-'+(e.level.currentSubLevel>0?e.level.currentSubLevel-1:0).toString());

    if (!e.level.hasNext() && !pauseState) {
      chapterComplete();
    }
  }

  static void resume(Event e) {
    hide();
    Input.keyDown = null;
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
    querySelector(".chapter-rating").innerHtml = totalStars.toString();
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
    e.saveCurrentProgress();
    Level.navigateToLevel(int.parse((evt.currentTarget as
        DivElement).dataset['level']), e);
  }

  static void hide() {
    if (GameWizard.showing) {
      fadeBoxIn(GameWizard.progress, 175);
    }

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
