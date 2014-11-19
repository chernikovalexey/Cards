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

CanvasElement canvas;
GameEngine engine;
ParallaxManager parallax;
StateManager manager;
HintManager hints;
FeatureManager featureManager;

void main() {
    StarManager.init();

    featureManager = new FeatureManager();

    canvas = (querySelector("#graphics") as CanvasElement);
    print(canvas);
    CanvasRenderingContext2D g = canvas.getContext('2d');

    updateCanvasPositionAndDimension();

    // Load immediately because it is also used on the chapter end screen
    // In case `New Game` button is not pressed it will be also available
    Chapter.load();

    manager = new StateManager(g);
    engine = new GameEngine(g);
    manager.addState(new ParallaxManager(engine, g, 24, 175));

    canvas.onMouseMove.listen(Input.onMouseMove);
    canvas.onMouseDown.listen(Input.onMouseDown);

    // release the mouse no matter where it currently is
    window.onMouseUp.listen(Input.onMouseUp);
    canvas.onMouseWheel.listen(Input.onMouseWheel);
    canvas.onContextMenu.listen(Input.onContextMenu);

    window.onKeyDown.listen(Input.onKeyDown);
    window.onKeyUp.listen(Input.onKeyUp);
    window.onResize.listen(updateCanvasPositionAndDimension);
    window.onBeforeUnload.listen((Event event) {
        engine.saveCurrentProgress();

        if (engine.level != null && engine.level.current != null) {
            WebApi.updateAttemptsAmount(engine.level.current.attemptsUsed);
        }
    });

    showMainMenu();

    querySelector("#continue").addEventListener("click", (event) {
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
        querySelector("#menu-box").classes.add("hidden");

        fadeBoxIn(querySelector("#chapter-selection"));
        Chapter.load((List chapters) {
            ChapterShower.show(chapters);
        });
    }, false);

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

        //fadeBoxIn(querySelector(".friends"), 250, () {
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

    /*int attempts = UserManager.getAsInt("allAttempts");
    if (attempts == 0) {
        querySelector("#toggle-physics")
            ..classes.add("faded")
            ..title = "You've spent all attempts for today";
        //WebApi.attemptsRanOut(engine.level.current.attemptsUsed);
    }*/

    querySelector('#toggle-physics').addEventListener("click", (event) {
        if (!(event.target as ButtonElement).classes.contains("rewind")) {
            int attempts = UserManager.getAsInt("allAttempts");
            if (attempts > 0) {
                UserManager.decrement("allAttempts");
                applyRewindLabelToButton();
                ++engine.level.current.attemptsUsed;
                UserManager.decrement("allAttempts");

                if (!updateAttempts()) {
                    WebApi.updateAttemptsAmount(engine.level.current.attemptsUsed);
                }
            } else {
                PromptWindow.showSimple("Lack of attempts", "You've unfortunately spent all attempts for today. Come back tomorrow, or:", "Get more attempts", hints.getMoreHints);
                WebApi.updateAttemptsAmount(engine.level.current.attemptsUsed);
            }
        } else {
            applyPhysicsLabelToButton();
        }
    }, false);
    querySelector("#zoom-in").addEventListener("click", (event) => engine.zoom(true));
    querySelector("#zoom-out").addEventListener("click", (event) => engine.zoom(false));
    querySelector("#restart").addEventListener("click", (event) => engine.clear(), false);

    //updateBlockButtons(engine);

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
    if (attempts == 0) {
        querySelector("#toggle-physics")
            ..classes.add("faded")
            ..title = "You've spent all attempts for today";
        return false;
    }
    return true;
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

void applyPhysicsLabelToButton() {
    var btn = querySelector("#toggle-physics");
    btn.classes.remove("rewind");
    btn.text = "Apply physics";

    engine.rewind();
}

void applyRewindLabelToButton([List list]) {
    if (!engine.isRewinding) {
        //WebApi.addAttempt();

        var btn = querySelector("#toggle-physics");
        btn.classes.add("rewind");
        btn.text = "Rewind blocks";

        engine.togglePhysics(true);
    }
}

void updateBlockButtons(GameEngine engine) {
    querySelectorAll(".selector").forEach((DivElement s) {
        s.classes.remove("current");
    });
    (querySelectorAll(".selector")[engine.staticBlocksSelected ? 1 : 0] as DivElement).classes.add("current");

    querySelector(".static").hidden = engine.level.current.staticBlocksRemaining == 0;
    querySelector(".static .remaining").innerHtml = engine.level.current.staticBlocksRemaining.toString() + " left";
    querySelector(".dynamic .remaining").innerHtml = engine.level.current.dynamicBlocksRemaining.toString() + " left";
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