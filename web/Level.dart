import "dart:html";
import "dart:async";
import 'dart:convert';
import 'GameEngine.dart';
import 'package:box2d/box2d_browser.dart';
import "Sprite.dart";
import "SubLevel.dart";
import 'cards.dart';
import 'LevelSerializer.dart';
import 'GameWizard.dart';
import 'WebApi.dart';
import 'dart:js';
import 'JsMap.dart';
import 'package:animation/animation.dart';
import 'Scroll.dart';

class Level {
    GameEngine engine;
    SubLevel current;
    List<SubLevel> subLevels = new List();
    int currentSubLevel;
    List levels;

    int chapter;

    Level(Function ready, int chapter, GameEngine engine, bool _continue) {
        preload(ready, chapter, _continue);

        this.chapter = chapter;
        this.engine = engine;
    }

    // real amount minus one

    int findLastEmptyLevel(int ch) {
        int index = 0;
        while (window.localStorage.containsKey("level_" + ch.toString() + "_" + (++index).toString())) {
        }
        return index - 1 >= levels.length ? levels.length - 1 : index - 1;
    }

    void preload(Function ready, int chapter, bool _continue) {
        Storage storage = window.localStorage;

        HttpRequest.getString("levels/chapter_" + chapter.toString() + ".json").then((String str) {
            levels = JSON.decode(str)["levels"];

            Map last;
            if (_continue || (storage.containsKey("last") && (last = JSON.decode(storage["last"]))["chapter"] == chapter)) {
                last = JSON.decode(storage["last"]);
                currentSubLevel = last["level"];
                loadCurrent();
            } else {
                currentSubLevel = findLastEmptyLevel(chapter);
                next();
            }

            ready();

            for (int i = 0; i < currentSubLevel; ++i) {
                String level = 'level_' + chapter.toString() + '_' + (i + 1).toString();

                if (storage.containsKey(level) && !engine.manuallyControlled) {
                    LevelSerializer.fromJSON(storage[level], engine, i + 1 != currentSubLevel ? subLevels[i] : null);
                    if (i + 1 != currentSubLevel) {
                        subLevels[i].complete();
                    }
                }
            }
        });
    }

    void next() {
        if (hasNext()) {
            if (current != null) {
                current.enable(false);
            }
            ++currentSubLevel;
            loadCurrent();
        }
    }

    void loadCurrent() {
        if (currentSubLevel > subLevels.length) {
            for (int i = subLevels.length; i < currentSubLevel; ++i) {
                subLevels.add(load(i + 1));
            }

            WebApi.levelStart(chapter, currentSubLevel);
        } else {
            current = subLevels[currentSubLevel - 1];
            current.apply();
            current.online(true);
        }

        GameWizard.manage(chapter, current.index);
        handleLevelChange();
        updateBlockButtons(engine);

        // Check friends

        toggleFinishedFriends();
    }

    void toggleFinishedFriends() {
        DivElement finished = querySelector('.friends-finished') as DivElement;
        Map fchapter = context['Features']['chapters'][engine.level.chapter.toString()];

        if (fchapter != null) {
            animate(finished, properties: {
                'opacity': 1.0
            }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);

            JsObject flevel_js = fchapter[engine.level.currentSubLevel.toString()];

            if (flevel_js != null) {
                JsMap flevel = new JsMap.fromJsObject(flevel_js);

                print("This level was finished by friends: " + engine.level.currentSubLevel.toString());

                finished.innerHtml = flevel.length.toString() + " friend(s) finished this level";

                finished.addEventListener("click", (event) {
                    DivElement box = querySelector('#friends-finished') as DivElement;
                    box.classes.remove('hidden');
                    animate(box, properties: {
                        'top': 0, 'opacity': 1.0
                    }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);

                    new Timer(new Duration(milliseconds: 125), () {
                        context['Features'].callMethod('showFinishedFriends', [engine.level.chapter, engine.level.currentSubLevel, () {
                            querySelector(".game-box").classes.add("blurred");

                            var bar = Scroll.setup('finished-vs', 'finished-es', 'finished-scrollbar');
                            context['dw_Scrollbar_Co'].callMethod('addEvent', [bar, 'on_scroll', (var x, var y) {
                                //print("scrolling");
                            }]);
                        }]);
                    });
                }, true);

                querySelector(".close-finished").addEventListener("click", (event) {
                    querySelector('.game-box').classes.remove('blurred');
                    animate(querySelector('#friends-finished'), properties: {
                        'top': 800, 'opacity': 0.0
                    }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);
                }, false);
            }
        } else {
            animate(finished, properties: {
                'opacity': 0.0
            }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);
        }
    }

    void previous() {
        if (hasPrevious()) {
            --currentSubLevel;
            current.saveState();
            current.online(false);
            current = subLevels[currentSubLevel - 1];
            current.apply();
            handleLevelChange();
        }
    }

    void handleLevelChange() {
        showLevelName(subLevels[currentSubLevel - 1].name);

        window.localStorage["last"] = JSON.encode({
            'chapter': chapter, 'level': currentSubLevel
        });
    }

    bool hasNext() {
        return levels.length >= currentSubLevel + 1;
    }

    bool hasPrevious() {
        return currentSubLevel > 1;
    }

    SubLevel load(int level) {
        current = new SubLevel(engine, levels[level - 1], level);
        return current;
    }

    int getRating() {
        int min = 3;
        for (SubLevel sl in subLevels) {
            if (sl.rating < min) min = sl.rating;
        }

        return min;
    }

    static int targetLevel;
    static SubLevel last;
    static GameEngine eng;

    static void navigateToLevel(int target, GameEngine _eng) {
        eng = _eng;
        targetLevel = target;
        if (targetLevel == eng.level.currentSubLevel) {
            eng.restartLevel();
        } else if (target < eng.level.currentSubLevel) {
            last = eng.level.current;
            eng.frontRewind = false;
            eng.level.previous();
            eng.level.current.levelApplied = onLevelApplied;
        } else {
            eng.frontRewind = true;
            if (!eng.physicsEnabled) {
                applyRewindLabelToButton();
                eng.frontRewindLevelComplete = onFrontRewindLevelComplete;
                eng.frontRewindLevelFailed = onFrontRewindLevelFailed;
            }
            //eng.level.next();
        }
    }

    static void onFrontRewindLevelComplete() {
        //print("onFrontRewindLevelComplete");
        //print("target: "+targetLevel.toString()+" current: "+ eng.level.currentSubLevel.toString());
        if (targetLevel != eng.level.currentSubLevel) {
            eng.level.next();
            applyRewindLabelToButton();
        } else {
            eng.frontRewind = false;
        }

    }

    static void onFrontRewindLevelFailed() {
        window.alert("The system is broken! Please repair this level to continue.");
        eng.frontRewind = false;
        applyPhysicsLabelToButton();
    }

    static void onLevelApplied() {
        last.frames.clear();
        if (targetLevel < eng.level.currentSubLevel) {
            eng.level.previous();
            eng.level.current.levelApplied = onLevelApplied;
        } else if (targetLevel == eng.level.currentSubLevel) {
            eng.level.current.levelApplied = null;
            applyPhysicsLabelToButton();
        }
    }
}
