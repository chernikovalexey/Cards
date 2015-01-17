import 'dart:html';
import "cards.dart";
import 'Tooltip.dart';
import 'dart:async';
import 'dart:js';
import 'RatingShower.dart';
import 'dart:math' as Math;
import 'package:box2d/box2d_browser.dart';
import 'package:animation/animation.dart';
import 'GameEngine.dart';
import 'Input.dart';
import 'EnergySprite.dart';
import 'PromptWindow.dart';

class GameWizard {
    static const int ANIM_TIME = 175;

    static Storage storage = window.localStorage;

    static Element currentBox;

    // current box
    static Element progress = querySelector(".tutorial-progress");

    static bool showing = false;

    static void enterStep(Element box, [Function callback]) {
        if (currentBox != box) {
            PromptWindow.close();

            var setNewBox = () {
                fadeBoxIn(box, ANIM_TIME, callback);
                currentBox = box;
            };

            if (currentBox != null) {
                fadeBoxOut(currentBox, ANIM_TIME, setNewBox);
            } else {
                setNewBox();
            }
        }
    }

    static void finish() {
        showing = false;

        if (currentBox != null) {
            fadeBoxOut(currentBox, ANIM_TIME);
            fadeBoxOut(progress, ANIM_TIME);
            Tooltip.closeAll();
        }
    }

    static void nextStep() {
        Element active = querySelector(".active-step");
        active.classes.remove("active-step");
        active.nextElementSibling.classes.add("active-step");
    }

    static bool isTutorial(int chapter, int level) {
        return true;
    }

    static void init() {
        querySelectorAll(".progress-step").onClick.listen((event) {
            if (event.target.classes.contains("wizard-controls")) {
                enterStep(querySelector("#wizard-controls"), () {
                    Tooltip.closeAll();
                    RatingShower.blurGameBox();
                });
            } else if (event.target.classes.contains("wizard-try")) {
                enterStep(querySelector("#wizard-try"), () {
                    RatingShower.unblurGameBox();
                });
            }
        });

        querySelector(".show-goal").onClick.listen((event) {
            showHowto();
        });
    }

    static void manage(int chapter, int level) {
        if (chapter == 1 && level == 1) {
            showOverview();
        } else if (chapter == 1 && level == 3) {
            showRotation();
        } else if (chapter == 1 && level == 5) {
            showZoom();
        } else if (chapter == 1 && level == 8) {
            showStaticAppear();
        } else if (chapter == 3 && level == 1) {
            showDynamicObstacles();
        }

        tryShowingHintsTooltip();
    }

    static void showHowto([Function closeCallback = null]) {
        Tooltip.closeAll();

        querySelector("#tutorial-player").attributes['src'] = context['Features']['tutorial_img'].src;// + "?v=" + new DateTime.now().millisecondsSinceEpoch.toString();

        querySelector('#howto').classes.remove("hidden");
        animate(querySelector('#howto'), properties: {
            'top': 0, 'opacity': 1.0
        }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);

        querySelector(".close-howto").style.opacity = "0.0";

        new Timer.periodic(new Duration(milliseconds: 225), (Timer timer) {
            if (context.callMethod('imageLoaded', [context['Features']['tutorial_img']])) {
                animate(querySelector('.howto-loading'), properties: {
                    'opacity': 0.0
                }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);

                animate(querySelector('#tutorial-player'), properties: {
                    'opacity': 1.0
                }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);

                timer.cancel();
            }
        });

        var showClose = () {
            animate(querySelector(".close-howto"), properties: {
                'opacity': 0.5
            }, duration: 350, easing: Easing.SINUSOIDAL_EASY_IN);

            storage['seen_howto'] = 'true';
        };

        if (storage.containsKey("seen_howto")) {
            showClose();
        } else {
            new Timer(new Duration(seconds: 8), showClose);
        }

        var frames = [{
            'time': 0, 'text': context['locale']['wizard_place']
        }, {
            'time': 3500, 'text': context['locale']['wizard_apply']
        }, {
            'time': 7000, 'text': context['locale']['goal_desc']
        }];

        var change = () {
            for (var i = 0, len = frames.length; i < len; ++i) {
                String text = frames[i]['text'];
                new Timer(new Duration(milliseconds: frames[i]['time']), () {
                    querySelector('.howto-goal').innerHtml = text;
                });
            }
        };

        new Timer.periodic(new Duration(milliseconds: 40500), (Timer timer) => change());
        change();

        querySelector(".close-howto").addEventListener("click", (event) {
            animate(querySelector('#howto'), properties: {
                'top': 800, 'opacity': 0.0
            }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);

            if (closeCallback != null) {
                closeCallback();
            }
        }, false);
    }

    static void showOverview() {
        showing = true;

        var showTooltips = () {
            if (engine.cards.isEmpty) {
                hints.addHintCard(1.671, 2.5, 0.0, 1.0, false);

                var cb = (Event event) {
                    if (event.target.classes.contains("ignore-close-all")) return;

                    Tooltip.closeAll();
                    hints.clearHintCards();

                    Tooltip.show(querySelector("#toggle-physics"), context['locale']['wizard_apply'], Tooltip.BOTTOM, maxWidth: 300);

                    var toggleStream = querySelector("#toggle-physics").onClick.listen((event) {
                        Tooltip.closeAll();
                    });

                    querySelector("#toggle-physics").onClick.listen((event) {
                        toggleStream.cancel();
                    });
                };

                Tooltip.showSimple(context['locale']['wizard_place'], Input.canvasX + 225, 335);

                var bodyStream = querySelector("body").onClick.listen(cb);

                querySelector("body").onClick.listen((event) {
                    bodyStream.cancel();
                });
            }
        };

        if (!storage.containsKey("seen_howto")) {
            showHowto(showTooltips);
        } else {
            showTooltips();
        }
    }

    static void showGoal() {
        engine.canFinishLevel = false;
        Tooltip.showSimple(context['locale']['goal_desc'], Input.canvasX + 200, 300, () {
            engine.canFinishLevel = true;
        }, context['locale']['goal']);
    }

    static void showRunout() {
        if (!storage.containsKey("runout_occured") && manager.states.contains(engine)) {
            Tooltip.show(querySelector(".dynamic"), context['locale']['wizard_limited_amount'], Tooltip.RIGHT, maxWidth: 300, closeDelay: 1500);
            storage["runout_occured"] = "true";
        }
    }

    static void showRewind() {
        if (!storage.containsKey("apply_fail_occured") && manager.states.contains(engine)) {
            Tooltip.show(querySelector("#toggle-physics"), context['locale']['wizard_rewind'], Tooltip.BOTTOM, maxWidth: 300, callback: () {
                Tooltip.showSimple(context['locale']['wizard_remove'], Input.canvasX + 200, 225);

                var bodyStream = querySelector("body").onContextMenu.listen((event) {
                    if (event.target.classes.contains("ignore-close-all")) return;
                    Tooltip.closeAll();
                });

                querySelector("body").onContextMenu.listen((event) {
                    bodyStream.cancel();
                });
            });
            storage["apply_fail_occured"] = "true";
        }
    }

    static bool showingRotation = false;

    static void showRotation() {
        new Timer(new Duration(seconds: 1), () {
            if (manager.states.contains(engine)) {
                showingRotation = true;
                Tooltip.showSimple(context['locale']['wizard_rotate'], Input.canvasX + 100, 285);
            }
        });
    }

    static void onBlockRotate() {
        if (showingRotation) {
            showingRotation = false;
            new Timer(new Duration(milliseconds: 475), () {
                Tooltip.closeAll();
            });
        }
    }

    static void tryShowingHintsTooltip() {
        new Timer.periodic(new Duration(milliseconds: 90000), (Timer timer) {
            if (manager.states.contains(engine) && !engine.isPaused && anyWindowsOpened()) {
                Tooltip.show(querySelector("#hint"), context['locale']['wizard_hints'], Tooltip.BOTTOM, maxWidth: 300, xOffset: -90);

                var stream = querySelector("#hint").onClick.listen((event) {
                    Tooltip.closeAll();
                });

                querySelector("#hint").onClick.listen((event) {
                    stream.cancel();
                });
            }
        });
    }

    static void showZoom() {
        new Timer(new Duration(seconds: 3), () {
            if (manager.states.contains(engine)) {
                Tooltip.show(querySelector("#zoom-out"), context['locale']['wizard_zoom'], Tooltip.BOTTOM, maxWidth: 300, xOffset: -30, xArrowOffset: -25);

                querySelectorAll(".zb").forEach((el) {
                    var stream = el.onClick.listen((event) {
                        Tooltip.closeAll();
                    });

                    el.onClick.listen((event) {
                        stream.cancel();
                    });
                });
            }
        });
    }

    static void showStaticAppear() {
        Element _static = querySelector(".static");
        new Timer(new Duration(seconds: 1), () {
            if (!_static.hidden) {
                Tooltip.show(_static, context['locale']['wizard_static'], Tooltip.RIGHT, maxWidth: 300, yOffset: 0, yArrowOffset: -3);
            }
        });
    }

    static void showDynamicObstacles() {
        new Timer(new Duration(seconds: 1), () {
            Tooltip.showSimple(context['locale']['dynamic_obstacles_tooltip'], 240, 300);
        });
    }
}