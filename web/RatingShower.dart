import "dart:html";
import "GameEngine.dart";
import "SubLevel.dart";
import "Level.dart";
import "Input.dart";
import "cards.dart";
import "Scroll.dart";
import 'package:animation/animation.dart';
import 'dart:async';
import 'dart:js';
import "StarManager.dart";
import 'UserManager.dart';
import 'GameWizard.dart';
import 'WebApi.dart';
import 'Tooltip.dart';
import 'Chapter.dart';
import 'ChapterShower.dart';
import 'package:sprintf/sprintf.dart';

class RatingShower {
    static const int FADE_TIME = 450;
    static int oldRating, newRating;

    static GameEngine e;
    static bool wasJustPaused = false;

    static bool pauseState = false;

    static void nextLevel(Event event) {
        int attempts = e.level.current.attemptsUsed;
        e.level.current.attemptsUsed = 0;

        if (e.level.currentSubLevel != e.level.subLevels.length) {
            print("current sublevel != sublevels.length");
            onTypeItemClick(event);
            return;
        }

        WebApi.finishLevel(newRating, engine.countCards(true), engine.countCards(false), attempts);

        hide();

        GameWizard.finish();

        e.nextLevel();
        e.isPaused = false;

        updateBlockButtons(e);
        event.stopPropagation();
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

        for (int i = 1; i <= e.level.levels.length; ++i) {
            ti.classes.remove("ti-" + i.toString());
        }

        String levelIndex = (index + 1).toString();
        ti.dataset['level'] = levelIndex;
        ti.classes.add("ti-" + levelIndex);

        ti.classes.remove("tape-current-item");
        ti.classes.remove("locked");

        tr.classes.clear();
        tr.classes.add("tape-rating");

        if (index >= e.level.subLevels.length) {
            ti.classes.add("locked");
        } else {
            tr.innerHtml = getStars(e.level.subLevels[index].rating);
        }

        if (index == current) ti.classes.add("tape-current-item");

        ti.id = chapter.toString() + "-" + levelIndex;

        return el.innerHtml;
    }

    static String getStars(int stars) {
        DivElement tpl = querySelector(".star-template") as DivElement;
        int passed = 1;
        for (var star in tpl.querySelectorAll(".star")) {
            if (passed++ <= stars) {
                star.classes.remove("extinct-star");
            } else {
                star.classes.add("extinct-star");
            }
        }
        return tpl.innerHtml;
    }

    static void show(GameEngine engine, int rating, [int oldR = 0]) {
        /*if (GameWizard.showing) {
            querySelector(".tutorial-layout").classes.remove("hidden");
            querySelector(".attempts-layout").classes.add("hidden");
            GameWizard.finish();
        } else {*/
            querySelector(".tutorial-layout").classes.add("hidden");
            querySelector(".attempts-layout").classes.remove("hidden");
        //}

        oldRating = oldR;
        newRating = rating;
        e = engine;
        e.isPaused = true;
        //querySelector(".chapter-controls").classes.add("hidden");

        querySelector(".game-box").classes.add("paused");
        querySelector(".level-name").style.display = "none";

        new Timer(new Duration(milliseconds: 87), () {
            blurGameBox();
        });
        fadeBoxIn(querySelector("#rating-box"), 175);

        querySelector(".rating-wrap").classes.remove("hidden");
        querySelector(".chapter-rating-wrap").classes.add("hidden");
        querySelector(".level-rating").innerHtml = getStars(rating);
        querySelector(".s-level-name").innerHtml = e.level.current.name;

        var chapterLevel = querySelector(".chapter-level");
        chapterLevel.querySelector(".finished-levels").innerHtml = e.level.current.index.toString();
        chapterLevel.querySelector(".all-levels").innerHtml = e.level.levels.length.toString();

        querySelector("#next-level").focus();
        querySelector("#next-level").removeEventListener("click", nextLevel);
        querySelector("#next-level").addEventListener("click", nextLevel);
        querySelector("#restart-level").removeEventListener("click", restartLevel);
        querySelector("#restart-level").addEventListener("click", restartLevel);

        querySelector("#tape-es").innerHtml = "";
        String s = "";
        for (int i = 0; i < e.level.levels.length; i++) {
            s += tapeItem(e.level.levels[i], e.level.chapter, i, e.level.currentSubLevel - 1);
        }

        final NodeValidatorBuilder _htmlValidator = new NodeValidatorBuilder.common()
            ..allowElement('div', attributes: ['data-target', 'data-level']);

        (querySelector("#tape-es") as DivElement).setInnerHtml(s, validator:_htmlValidator);

        DivElement nextTapeItem = querySelector(".ti-" + (e.level.currentSubLevel + 1).toString());
        if (nextTapeItem != null && !pauseState) {
            nextTapeItem.querySelectorAll(".star").forEach((Element el) {
                el.classes.add("extinct-star");
            });
            nextTapeItem.classes.remove("locked");
        }

        for (DivElement element in querySelectorAll(".tape-item")) {
            if (element.classes.contains("ti-" + (e.level.currentSubLevel + 1).toString()) && !element.classes.contains("locked")) {
                element.removeEventListener("click", nextLevel);
                element.addEventListener("click", nextLevel);
            } else if (!element.classes.contains('locked')) {
                element.removeEventListener("click", onTypeItemClick);
                element.addEventListener("click", onTypeItemClick);
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
            //querySelector(".chapter-controls").classes.add("hidden");
            //querySelector("#pm-menu").removeEventListener("click", mainMenu);
            querySelector("#pm-menu").addEventListener("click", (event) => mainMenu(engine));
            querySelector("#resume-game")
                ..removeEventListener("click", resume)
                ..addEventListener("click", resume, false);
            querySelector(".level-rating").classes.add('hidden');

            querySelector(".rating-inner-layout").classes.remove("small-margin");
        } else {
            querySelector(".level-controls").classes.remove('hidden');
            querySelector(".pause-controls").classes.add('hidden');
            querySelector(".level-rating").classes.remove('hidden');
            querySelector(".pause-title").classes.add('hidden');

            //
            querySelector(".rating-inner-layout").classes.add("small-margin");

            //
//            querySelector("#share-level").addEventListener("click", (event) {
//                context['Features'].callMethod('prepareLevelWallPost', [e.level.current.name, getStars(rating)]);
//            }, true);
        }

        querySelector(".attempts-left").innerHtml = sprintf(context['locale']['attempts_left'], [UserManager.getAsInt('boughtAttempts') == -1 ? '∞' : UserManager.get("allAttempts").toString(), context['Features'].callMethod('getNounPlural', [UserManager.get("allAttempts"), context['locale']['attempt_form1'], context['locale']['attempt_form2'], context['locale']['attempt_form3']])]);
        querySelector(".get-attempts-button").removeEventListener("click", showPurchases);
        querySelector(".get-attempts-button").addEventListener("click", showPurchases, true);

        querySelector("#tape-es").style.width = (e.level.levels.length * 172 + 10).toString() + "px";
        Scroll.setup('tape-vs', 'tape-es', 'tape-scrollbar', 'h');
        Scroll.scrollTo('tape-vs', e.level.chapter.toString() + '-' + (e.level.currentSubLevel > 0 ? e.level.currentSubLevel - 1 : 0).toString());

        if (!e.level.hasNext() && !pauseState) {
            chapterComplete(engine, rating);
        }

        if (pauseState) {
            Input.attachSingleEscClickCallback(hide);
        }
    }

    static void showPurchases([Event event]) {
        hide();
        hints.getMoreHints();
    }

    static void blurGameBox() {
        querySelector("#graphics").classes.add("blurred");
        querySelector(".buttons").classes.add("blurred");
        querySelector(".selectors").classes.add("blurred");
    }

    static void unblurGameBox() {
        querySelector("#graphics").classes.remove("blurred");
        querySelector(".buttons").classes.remove("blurred");
        querySelector(".selectors").classes.remove("blurred");
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

    static void chapterComplete(GameEngine engine, int rating) {
        querySelector(".rating-wrap").classes.add("hidden");
        querySelector(".chapter-rating-wrap").classes.remove("hidden");
        querySelector(".pause-controls").classes.add("hidden");
        querySelector(".level-controls").classes.add("hidden");
        //querySelector(".chapter-controls").classes.remove("hidden");
        int totalStars = 0;
        for (SubLevel l in e.level.subLevels) {
            totalStars += l.rating;
        }
        querySelector(".chapter-rating").innerHtml = totalStars.toString();
        //querySelector("#cm-menu").addEventListener('click', mainMenu);
        querySelector("#cc-list").addEventListener("click", (event) {
            hide();
            manager.removeState(engine);
            querySelector(".buttons").classes.add("hidden");
            querySelector(".selectors").classes.add("hidden");
            fadeBoxIn(querySelector("#chapter-selection"));
            ChapterShower.show(Chapter.chapters);
        }, true);

        querySelector(".attempts-layout").classes.add("hidden");

        querySelector(".current-level-name")
            ..classes.remove("hidden")
            ..innerHtml = engine.level.current.name;
        querySelector(".current-level-rating").innerHtml = getStars(rating);

        querySelector(".current-chapter-name")
            ..classes.remove("hidden")
            ..innerHtml = Chapter.chapters[engine.level.chapter - 1]['name'];

        window.localStorage.remove("last");
    }

    static void mainMenu(GameEngine e) {
        hide();
        showMainMenu();

        // If the level name is being shown currently, hide it swift
        animate(querySelector(".level-name"), properties: {
            'margin-top': -20, 'opacity': 0.0, 'font-size': 32
        }, duration: 1, easing: Easing.SINUSOIDAL_EASY_IN_OUT);
    }

    static void onTypeItemClick(Event evt) {
        hide();
        e.isPaused = false;
        e.saveCurrentProgress();

        int level;

        if (evt.currentTarget is DivElement) {
            level = int.parse((evt.currentTarget as DivElement).dataset['level']);
        } else if (evt.currentTarget is ButtonElement) {
            level = int.parse(querySelector(".tape-current-item").dataset['level']) + 1;
        }

        print("navigate to: " + level.toString());

        Level.navigateToLevel(level, e);
    }

    static void hide() {
        if (GameWizard.showing) {
            fadeBoxIn(GameWizard.progress, 175);
            querySelector("#wizard-overview").classes.remove("blurred");
        }

        Input.removeSingleEscClickCallback();
        e.isPaused = false;

        wasJustPaused = true;
        unblurGameBox();

        fadeBoxOut(querySelector("#rating-box"), 175, () {
            querySelector(".level-name").style.display = "block";
            querySelector(".game-box").classes.remove("paused");
        });
    }
}
