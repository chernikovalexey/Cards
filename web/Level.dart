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
import 'UserManager.dart';
import 'Input.dart';
import 'Tooltip.dart';
import 'PromptWindow.dart';

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
        bool found = false;
        while (!found) {
            ++index;
            if (window.localStorage.containsKey("level_" + ch.toString() + "_" + index.toString())) {
                Map json = JSON.decode(window.localStorage["level_" + ch.toString() + "_" + index.toString()]);
                if (!json["completed"]) {
                    found = true;
                    --index;
                    break;
                }
            }
            if (index == 12) {
                found = true;
            }
        }

        int level = (index >= levels.length ? levels.length : index) - 1;
        return (level >= 0 ? level : 0) + 1;
    }

    List<Map> getLevelsFrom(int chapter, int from) {
        List<Map> levels = new List<Map>();
        for (int i = from; i <= 12;++i) {
            String level = 'level_' + chapter.toString() + '_' + i.toString();

            if (!window.localStorage.containsKey(level)) {
                break;
            } else {
                levels.add(JSON.decode(window.localStorage[level]));
            }
        }
        return levels;
    }

    void preload(Function ready, int chapter, bool _continue) {
        Storage storage = window.localStorage;

        HttpRequest.getString("levels/chapter_" + chapter.toString() + ".json").then((String str) {
            levels = JSON.decode(str)["levels"];

            Map last;
            if (_continue || (storage.containsKey("last") && (last = JSON.decode(storage["last"]))["chapter"] == chapter)) {
                print("has the current");
                last = JSON.decode(storage["last"]);
                currentSubLevel = last["level"];
                loadCurrent();
            } else {
                print("find last empty");

                currentSubLevel = findLastEmptyLevel(chapter);

                if (window.localStorage.containsKey("level_" + chapter.toString() + "_" + (currentSubLevel + 1).toString())) {
                    next();
                } else {
                    loadCurrent();
                }

                /*List<Map> furtherLevels = getLevelsFrom(chapter, currentSubLevel);
                if (!furtherLevels.isEmpty) {
                    for (int i = currentSubLevel; i <= currentSubLevel + furtherLevels.length; ++i) {
                        subLevels.add(load(i));
                        subLevels[i].enable(false);
                    }
                }*/
            }

            ready();

            for (int i = 0; i < currentSubLevel; ++i) {
                String level = 'level_' + chapter.toString() + '_' + (i + 1).toString();

                // Double-check whether the level is completed
                if (storage.containsKey(level) && !engine.manuallyControlled) {
                    bool completed = LevelSerializer.fromJSON(storage[level], engine, i + 1 != currentSubLevel ? subLevels[i] : null);

                    if (i + 1 != currentSubLevel) {
                        subLevels[i].complete();
                    }
                }
            }
        });
    }

    void next() {
        print("in next method");
        if (hasNext()) {
            print("has next");
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
        //updateBlockButtons(engine);
    }

    void toggleFinishedFriends() {
        DivElement finished = querySelector('.friends-finished-button') as DivElement;
        Map fchapter = context['Features']['chapters'][engine.level.chapter.toString()];

        if (fchapter != null) {
            JsObject flevel_js = fchapter[engine.level.currentSubLevel.toString()];

            if (flevel_js != null) {
                finished.classes.remove("hidden");

                JsMap flevel = new JsMap.fromJsObject(flevel_js);

                print("Amount of friends finished this level: " + flevel.length.toString());

                querySelector(".friends-finished-amount").innerHtml = flevel.length.toString();

                finished.addEventListener("click", (event) {
                    PromptWindow.close();
                    Tooltip.closeAll();

                    DivElement box = querySelector('#friends-finished') as DivElement;
                    box.classes.remove('hidden');
                    animate(box, properties: {
                        'top': 0, 'opacity': 1.0
                    }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);

                    new Timer(new Duration(milliseconds: 125), () {
                        context['Features'].callMethod('showFinishedFriends', [engine.level.chapter, engine.level.currentSubLevel, () {
                            querySelector(".game-box").classes.add("blurred");

                            Input.attachSingleEscClickCallback(() {
                                querySelector(".close-finished").click();
                            });

                            var bar = Scroll.setup('finished-vs', 'finished-es', 'finished-scrollbar');
                            context['dw_Scrollbar_Co'].callMethod('addEvent', [bar, 'on_scroll', (var x, var y) {
                                querySelector("#finished-blur-g").style.transform = "translatey(" + (y + 80).toString() + "px)";
                            }]);

                            context.callMethod('html2canvas', [querySelector('#finished-es'), new JsObject.jsify({
                                'onrendered': (CanvasElement canvas) {
                                    canvas.id = "finished-blur-g";
                                    querySelector("#friends-finished .bs-screen-blurry-bar").append(canvas);
                                    CanvasRenderingContext2D g = canvas.getContext('2d');
                                    g.fillStyle = 'rgba(0, 0, 0, 0.5)';
                                    g.fillRect(0, 0, canvas.width, canvas.height);
                                }
                            })]);
                        }]);
                    });
                }, true);

                querySelector(".close-finished").addEventListener("click", (event) {
                    querySelector('.game-box').classes.remove('blurred');
                    animate(querySelector('#friends-finished'), properties: {
                        'top': 800, 'opacity': 0.0
                    }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);
                }, false);
            } else {
                finished.classes.add("hidden");
            }
        } else {
            finished.classes.add("hidden");
        }
    }

    void updateHints() {
        querySelector("#hints-amount").innerHtml = UserManager.getAsString("balance");
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
        toggleFinishedFriends();
        updateHints();
        updateBlockButtons(engine);

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
            print("front rewind");
            //if (!eng.physicsEnabled) {
            print("physics not enabled");
            applyRewindLabelToButton();
            eng.frontRewindLevelComplete = onFrontRewindLevelComplete;
            eng.frontRewindLevelFailed = onFrontRewindLevelFailed;
            //}
            //eng.level.next();
        }
    }

    static void onFrontRewindLevelComplete() {
        print("onFrontRewindLevelComplete");
        print("target: " + targetLevel.toString() + " current: " + eng.level.currentSubLevel.toString());
        if (targetLevel != eng.level.currentSubLevel) {
            eng.level.current.finish();
            eng.level.next();
            applyRewindLabelToButton();
        } else {
            eng.frontRewind = false;
        }

    }

    static void onFrontRewindLevelFailed() {
        //PromptWindow.showSimple("System is broken!", "Please, repair this level to continue.");
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
