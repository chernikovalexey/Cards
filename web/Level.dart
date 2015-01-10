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
import 'StarManager.dart';

class Level {
    GameEngine engine;
    SubLevel current;
    List<SubLevel> subLevels = new List();
    int currentSubLevel;
    List levels;

    int chapter;

    Level(Function ready, int _chapter, GameEngine engine, bool _continue) {
        preload(ready, _chapter, _continue);

        this.chapter = _chapter;
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
                if (!json["cd"] && !json["c"].isEmpty) {
                    found = true;
                    --index;
                    break;
                }
            } else {
                found = true;
            }
            if (index == 12) {
                found = true;
            }
        }

        int level = (index >= levels.length ? levels.length : index) - 1;
        return (level >= 0 ? level : 0) + 1;
    }

    // Returns unparsed strings of levels

    List<String> getLevelsFrom(int chapter, int from) {
        List<Map> levels = new List<Map>();
        for (int i = from; i <= 12;++i) {
            String level = 'level_' + chapter.toString() + '_' + i.toString();

            if (!window.localStorage.containsKey(level)) {
                break;
            } else {
                levels.add(window.localStorage[level]);
            }
        }
        return levels;
    }

    void preloadFurtherLevels() {
        List<String> furtherLevels = getLevelsFrom(chapter, currentSubLevel + 1);

        if (!furtherLevels.isEmpty) {
            for (int i = currentSubLevel + 1, li = 0; i <= currentSubLevel + furtherLevels.length; ++i, ++li) {
                subLevels.add(new SubLevel(engine, levels[i - 1], i, true));
                SubLevel further = subLevels[i - 1];
                LevelSerializer.fromJSON(furtherLevels[li], engine, further, true);
                further.online(false, true);
            }

            // Fix to cube
            current.to.userData = engine.to.userData = Sprite.to(engine.world);
            // Fix camera position
            current.alignCamera();
        }
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
                preloadFurtherLevels();
            } else {
                currentSubLevel = findLastEmptyLevel(chapter);

                if (window.localStorage.containsKey("level_" + chapter.toString() + "_" + (currentSubLevel + 1).toString())) {
                    next();
                } else {
                    loadCurrent();
                }

                preloadFurtherLevels();
            }

            ready();

            for (int i = 0; i < currentSubLevel; ++i) {
                String level = 'level_' + chapter.toString() + '_' + (i + 1).toString();

                // Double-check whether the level is completed
                if (storage.containsKey(level)) {
                    LevelSerializer.fromJSON(storage[level], engine, i + 1 != currentSubLevel ? subLevels[i] : null);

                    if (i + 1 != currentSubLevel) {
                        subLevels[i].complete();
                    }
                }
            }

            GameWizard.manage(chapter, current.index);
        });
    }

    void next() {
        if (hasNext()) {
            if (current != null) {
                current.enable(false);
                current.to.userData = Sprite.from(engine.world);
            }
            ++currentSubLevel;
            loadCurrent();
            GameWizard.manage(chapter, current.index);

            if (engine.currentZoom != 1.0) {
                engine.centerBetweenCubes(engine.currentZoom);
            }
        }
    }

    void loadCurrent() {
        if (currentSubLevel > subLevels.length) {
            for (int i = subLevels.length; i < currentSubLevel; ++i) {
                subLevels.add(load(i + 1));
            }

            engine.bobbin.erase();
            engine.obstaclesBobbin.erase();

            WebApi.levelStart(chapter, currentSubLevel);
        } else {
            current = subLevels[currentSubLevel - 1];
            current.apply();
            current.online(true);
        }

        handleLevelChange();
    }

    void toggleFinishedFriends() {
        DivElement finished = querySelector('.friends-finished-button') as DivElement;
        Map fchapter = context['Features']['chapters'][engine.level.chapter.toString()];

        if (fchapter != null) {
            JsObject flevel_js = fchapter[engine.level.currentSubLevel.toString()];

            if (flevel_js != null) {
                finished.classes.remove("hidden");

                JsMap flevel = new JsMap.fromJsObject(flevel_js);

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
        saveAsLastLevel();
    }

    void saveAsLastLevel() {
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
            saveStarsForLoadedLevels(_eng, target);
        } else if (target < eng.level.currentSubLevel) {
            saveStarsForLoadedLevels(_eng, target);

            last = eng.level.current;
            eng.frontRewind = false;
            eng.level.previous();
            eng.level.current.levelApplied = onLevelApplied;
        } else {
            eng.frontRewind = true;
            eng.frontRewindLevelComplete = onFrontRewindLevelComplete;
            eng.frontRewindLevelFailed = onFrontRewindLevelFailed;
        }
    }

    static void saveStarsForLoadedLevels(GameEngine _eng, int target) {
        for (int i = _eng.level.subLevels.length - 1; i >= target - 1; --i) {
            _eng.level.subLevels[i].rating = 0;
            toggleLevelCompletenessInStorage(_eng.level.chapter, i + 1, false);
        }
        StarManager.saveFrom(_eng.level.chapter, _eng.level.subLevels);
    }

    static void toggleLevelCompletenessInStorage(int chapter, int level, bool completed) {
        Storage storage = window.localStorage;
        String levelName = 'level_' + chapter.toString() + '_' + level.toString();

        if (storage.containsKey(levelName)) {
            Map json = JSON.decode(storage[levelName]);
            json['cd'] = completed;
            storage[levelName] = JSON.encode(json);
        }
    }

    static void onFrontRewindLevelComplete() {
        if (targetLevel != eng.level.currentSubLevel) {
            if (eng.level.current.finish()) {
                StarManager.saveFrom(eng.level.chapter, eng.level.subLevels);
                eng.level.next();
                applyRewindLabelToButton();
            }
        } else {
            eng.frontRewind = false;
        }
    }

    static void onFrontRewindLevelFailed() {
        //PromptWindow.showSimple("System is broken!", "Please, repair this level to continue.");
//        window.alert("The system is broken! Please repair this level to continue.");
        eng.frontRewind = false;
        applyPhysicsLabelToButton();
    }

    static void onLevelApplied() {
        last.frames.clear();
        last.obstaclesFrames.clear();

        if (targetLevel < eng.level.currentSubLevel) {
            eng.level.previous();
            eng.level.current.levelApplied = onLevelApplied;
        } else if (targetLevel == eng.level.currentSubLevel) {
            eng.level.current.levelApplied = null;
            applyPhysicsLabelToButton();
        }
    }
}
