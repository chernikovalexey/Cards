import 'dart:html';
import 'dart:convert';
import 'GameEngine.dart';
import 'Input.dart';
import 'package:animation/animation.dart';
import 'dart:async';
import 'ParallaxManager.dart';
import 'StateManager.dart';
import 'Chapter.dart';
import 'ChapterShower.dart';
import 'dart:js';
import "StarManager.dart";
import "HintManager.dart";
import 'UserManager.dart';
import 'FeatureManager.dart';
import 'WebApi.dart';
import 'GameWizard.dart';
import 'Scroll.dart';
import 'PromptWindow.dart';
import 'Tooltip.dart';
import 'package:sprintf/sprintf.dart';
import 'LevelSerializer.dart';

int lastAttemptsUsed = -1;

CanvasElement canvas;
GameEngine engine;
ParallaxManager parallax;
StateManager manager;
HintManager hints;
FeatureManager featureManager;

Function rateLimit(Function callback, int time) {
    bool waiting = false;

    Function rtn = (Event event) {
        if (waiting) return;
        waiting = true;
        new Timer(new Duration(milliseconds: time), () {
            waiting = false;
            callback(event);
        });
    };

    return rtn;
}

void main() {
    StarManager.init();

    featureManager = new FeatureManager();

    canvas = (querySelector("#graphics") as CanvasElement);
    CanvasRenderingContext2D g = canvas.getContext('2d');

    updateCanvasPositionAndDimension();

    manager = new StateManager(g);
    engine = new GameEngine(g);
    manager.addState(parallax = new ParallaxManager(engine, g, 24, 200));

    canvas.onMouseMove.listen(Input.onMouseMove);
    canvas.onMouseDown.listen(Input.onMouseDown);

    // release the mouse no matter where it currently is
    window.onMouseUp.listen(Input.onMouseUp);

    // Wheel rotation must be fixed at the same speed on all computers
    // E.g., on Macs it performs faster than on PCs
    // But must be the same indeed
    canvas.onMouseWheel.listen(rateLimit(Input.onMouseWheel, 18));

    canvas.onContextMenu.listen(Input.onContextMenu);

    window.onKeyDown.listen(Input.onKeyDown);
    window.onKeyUp.listen(Input.onKeyUp);
    window.onResize.listen(updateCanvasPositionAndDimension);

    bool updatedAttemptsUsed = false;

    window.onBeforeUnload.listen((Event event) {
        engine.saveCurrentProgress();

        if (engine.level != null && engine.level.current != null && !updatedAttemptsUsed) {
            WebApi.updateAttemptsAmount(engine.level.current.attemptsUsed);
            updatedAttemptsUsed = true;
        }
    });

    window.onUnload.listen((Event event) {
        if (engine.level != null && engine.level.current != null && !updatedAttemptsUsed) {
            WebApi.updateAttemptsAmount(engine.level.current.attemptsUsed);
            updatedAttemptsUsed = true;
        }
    });

    Element shareOffer = querySelector(".share-offer");
    Element logo = querySelector(".logo");
    Element instructions = querySelector(".instructions");

    Function slideMenuTop = () {
        animate(shareOffer, properties: {
            'top': -75
        }, easing: Easing.SINUSOIDAL_EASY_IN_OUT, duration: 125);

        animate(logo, properties: {
            'margin-top': 50
        }, easing: Easing.SINUSOIDAL_EASY_IN_OUT, duration: 225);

        animate(instructions, properties: {
            'margin-bottom': 115
        }, easing: Easing.SINUSOIDAL_EASY_IN_OUT, duration: 225);
    };

    Function onLoadedCallback = () {
        showMainMenu();

        Storage storage = window.localStorage;
        if (!storage.containsKey("last_share_offer") || new DateTime.now().difference(DateTime.parse(storage['last_share_offer'])).inHours >= 24) {
            storage['last_share_offer'] = new DateTime.now().toString();
            new Timer(new Duration(milliseconds: 750), () {
                animate(shareOffer, properties: {
                    'top': 17
                }, easing: Easing.SINUSOIDAL_EASY_IN_OUT, duration: 125);

                shareOffer.addEventListener("click", (event) {
                    context['Features'].callMethod('shareWithFriends', [slideMenuTop]);
                }, true);
            });
        } else {
            slideMenuTop();
        }

        Chapter.load((List chapters) {
            context['Features'].callMethod("hideLoading");

            LevelSerializer.syncVersions();

            querySelector("#continue").addEventListener("click", (event) {
                slideMenuTop();

                manager.removeState(engine);
                manager.addState(engine, {
                    'continue': true, 'chapter': JSON.decode(window.localStorage["last"])["chapter"]
                });

                updateAttempts();

                fadeBoxOut(querySelector("#menu-box"), 250, () {
                    updateCanvasPositionAndDimension();

                    querySelector(".buttons").classes.remove("hidden");
                    querySelector(".selectors").classes.remove("hidden");
                });
            }, false);

            querySelector("#new-game").addEventListener("click", (event) {
                slideMenuTop();

                querySelector("#menu-box").classes.add("hidden");

                fadeBoxIn(querySelector("#chapter-selection"));

                // Such an approach always gets the current list of chapters
                ChapterShower.show(Chapter.chapters);
            }, false);
        });

        int fp = context['Features']['friends_in_game'].length;

        String in_game = context['Features'].callMethod('getNounPlural', [fp, context['locale']['play_form1'], context['locale']['play_form2'], context['locale']['play_form3']]);
        String before = "";
        String after = "";

        if (context['qs']['app_lang'] == "en") after = in_game; else before = in_game;

        querySelector("#invite-friends").innerHtml = before + " <b>" + fp.toString() + " " + context['Features'].callMethod('getNounPlural', [fp, context['locale']['friend_form1'], context['locale']['friend_form2'], context['locale']['friend_form3']]) + "</b> " + after;
    };

    if (context['Features']['initialized']) {
        onLoadedCallback();
    } else {
        context['Features'].callMethod("setOnLoadedCallback", [onLoadedCallback]);
    }

    querySelector(".friends-invite-more").addEventListener("click", (event) {
        context['Features'].callMethod("showInviteBox");
    }, true);

    querySelector(".close-friends").addEventListener("click", (event) {
        querySelector('.game-box').classes.remove('blurred');
        animate(querySelector('.friends'), properties: {
            'top': 800, 'opacity': 0.0
        }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);
    }, false);

    querySelector("#invite-friends").addEventListener("click", (event) {
        querySelector('.friends').classes.remove("hidden");
        animate(querySelector('.friends'), properties: {
            'top': 0, 'opacity': 1.0
        }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);

        Input.attachSingleEscClickCallback(() {
            querySelector(".close-friends").click();
        });

        new Timer(new Duration(milliseconds: 125), () {
            context['Features'].callMethod('showFriendsBar', [() {
                querySelector(".game-box").classes.add("blurred");

                var bar = Scroll.setup('invitations-vs', 'invitations-es', 'invitations-scrollbar');
                context['dw_Scrollbar_Co'].callMethod('addEvent', [bar, 'on_scroll', (var x, var y) {
                    querySelector("#invitations-blur-g").style.transform = "translatey(" + (y + 80).toString() + "px)";
                }]);

                context.callMethod('html2canvas', [querySelector('#invitations-es'), new JsObject.jsify({
                    'onrendered': (CanvasElement canvas) {
                        canvas.id = "invitations-blur-g";
                        querySelector(".friends .bs-screen-blurry-bar").append(canvas);
                        CanvasRenderingContext2D g = canvas.getContext('2d');
                        g.fillStyle = 'rgba(0, 0, 0, 0.5)';
                        g.fillRect(0, 0, canvas.width, canvas.height);
                    }
                })]);
            }]);
        });
    });

    querySelector('#toggle-physics').addEventListener("click", (event) {
        if (!(event.target as ButtonElement).classes.contains("rewind")) {
            int attempts = UserManager.getAsInt("allAttempts");
            int boughtAttempts = UserManager.getAsInt("boughtAttempts");

            if (attempts > 0 || boughtAttempts == -1) {
                applyRewindLabelToButton();
            } else {
                PromptWindow.showSimple(context['locale']['attempts_lack'], context['locale']['attempts_lack_message'], context['locale']['get_attempts'], hints.getMoreHints);
                WebApi.updateAttemptsAmount(engine.level.current.attemptsUsed);
            }
        } else {
            applyPhysicsLabelToButton();
        }
    }, false);
    querySelector("#restart").addEventListener("click", promptGameRestart, false);
    querySelector("#zoom-in").addEventListener("click", (event) => engine.zoom(true));
    querySelector("#zoom-out").addEventListener("click", (event) => engine.zoom(false));

    querySelectorAll(".selector").forEach((DivElement el) {
        el.addEventListener("click", (event) {
            bool static = el.classes.contains("static");
            engine.staticBlocksSelected = static;
            updateBlockButtons(engine);
            el.classes.add("current");
        }, false);
    });

    hints = new HintManager(engine);
    querySelector("#hint").addEventListener("click", hints.onClick);
}

bool updateAttempts() {
    int attempts = UserManager.getAsInt("allAttempts");
    int boughtAttempts = UserManager.getAsInt("boughtAttempts");

    if (attempts == 0 && boughtAttempts != -1) {
        querySelector("#toggle-physics")
            ..classes.add("faded")
            ..title = context['locale']['spent_all_attempts'];
        return false;
    }

    return true;
}

void promptGameRestart([Event event]) {
    Tooltip.closeAll();

    PromptWindow.show(context['locale']['restart_question'], context['locale']['surely_want_restart'], '', '', () {
    }, (bool positive) {
        if (positive) {
            engine.clear();
        }

        PromptWindow.close();
    });
}

void showLevelName(String name) {
    if (!GameWizard.showing) {
        var el = querySelector(".level-name");

        el.innerHtml = name;
        el.style.display = "block";
        el.style.marginTop = "75px";

        animate(el, properties: {
            'margin-top': 60, 'opacity': 1.0, 'font-size': 24
        }, duration: 150, easing: Easing.SINUSOIDAL_EASY_IN_OUT);

        new Timer(new Duration(seconds: 3), () {
            animate(el, properties: {
                'margin-top': -20, 'opacity': 0.0, 'font-size': 32
            }, duration: 150, easing: Easing.SINUSOIDAL_EASY_IN_OUT);
        });
    }
}

void updateCanvasPositionAndDimension([Event event = null]) {
    if (canvas != null) {
        Rectangle r = canvas.getBoundingClientRect();
        Input.canvasX = r.left;
        Input.canvasY = r.top;
        Input.canvasWidth = r.width;
        Input.canvasHeight = r.height;

        //
        // Align selector (of blocks) buttons

        DivElement selectors = querySelector(".selectors");
        selectors.style.top = (r.top + r.height / 2 - 140 / 2).toString() + "px";
    }
}

void togglePhysicsLabel() {
    var btn = querySelector("#toggle-physics");
    if (btn.classes.contains("rewind")) {
        applyPhysicsLabelToButton();
    } else {
        applyRewindLabelToButton();
    }
}

void applyPhysicsLabelToButton([Function callback = null]) {
    var btn = querySelector("#toggle-physics");
    btn.classes.remove("rewind");
    btn.text = context['locale']['apply_physics'];

    engine.rewind(callback);
}

void applyRewindLabelToButton([List list]) {
    if (!engine.isRewinding) {
        var btn = querySelector("#toggle-physics");
        btn.classes.add("rewind");
        btn.text = context['locale']['rewind'];

        engine.togglePhysics(true);
    }
}

void updateBlockButtons(GameEngine engine) {
    querySelectorAll(".selector").forEach((DivElement s) {
        s.classes.remove("current");
    });
    (querySelectorAll(".selector")[engine.staticBlocksSelected ? 1 : 0] as DivElement).classes.add("current");

    querySelector(".static").hidden = engine.level.current.staticBlocksRemaining == 0;
    querySelector(".static .remaining").innerHtml = sprintf(context['locale']['left'], [engine.level.current.staticBlocksRemaining.toString()]);
    querySelector(".dynamic .remaining").innerHtml = sprintf(context['locale']['left'], [engine.level.current.dynamicBlocksRemaining.toString()]);
}

void showMainMenu() {
    // No continue button in case if there is nothing to proceed with
    engine.cards.clear();
    querySelector("#continue").hidden = !window.localStorage.containsKey("last");

    manager.removeState(engine);
    querySelector(".buttons").classes.add("hidden");
    querySelector(".selectors").classes.add("hidden");

    fadeBoxIn(querySelector("#menu-box"));
}

void blink(String selector) {
    Element btn = querySelector(selector);
    btn.classes.add("error-blink");
    new Timer(new Duration(milliseconds: 450), () {
        btn.classes.remove("error-blink");
    });
}

void blinkPhysicsButton() {
    blink("#toggle-physics");
}

void fadeBoxIn(DivElement box, [int duration = 500, Function callback]) {
    box.classes.remove("hidden");
    animate(box, properties: {
        'opacity': 1.0
    }, duration: duration, easing: Easing.SINUSOIDAL_EASY_OUT);
    if (callback != null) new Timer(new Duration(milliseconds: duration), callback);
}

void fadeBoxOut(DivElement box, [int duration = 500, Function callback]) {
    animate(box, properties: {
        'opacity': 0.0
    }, duration: duration, easing: Easing.SINUSOIDAL_EASY_IN);
    new Timer(new Duration(milliseconds: duration), () {
        box.classes.add("hidden");
        if (callback != null) callback();
    });
}

bool anyWindowsOpened() {
    bool opened = false;
    querySelectorAll(".bs-screen").forEach((Element element) {
        if (element.classes.contains("hidden") || element.style.opacity == "0.0") {
            opened = true;
        }
    });
    return opened;
}