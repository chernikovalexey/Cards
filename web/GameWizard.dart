import 'dart:html';
import "cards.dart";
import 'Tooltip.dart';
import 'dart:async';
import 'RatingShower.dart';
import 'dart:math' as Math;
import 'package:box2d/box2d_browser.dart';
import 'GameEngine.dart';
import 'Input.dart';
import 'EnergySprite.dart';

class GameWizard {
    static const int ANIM_TIME = 175;

    static Storage storage = window.localStorage;

    static Element currentBox;

    // current box
    static Element progress = querySelector(".tutorial-progress");

    static bool showing = false;

    static void enterStep(Element box, [Function callback]) {
        if (currentBox != box) {
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
    }

    static void manage(int chapter, int level) {
        if (chapter == 1 && level == 1) {
            showOverview();
        } else if (chapter == 1 && level == 3) {
            showRotation();
        } else if (chapter == 1 && level == 6) {
            showHintsTooltip();
        } else if (chapter == 1 && level == 5) {
            showZoom();
        } else if (chapter == 1 && level == 8) {
            showStaticAppear();
        }
    }

    static void showOverview() {
        showing = true;

        if (engine.cards.isEmpty) {
            hints.addHintCard(1.671, 2.5, 0.0, 1.0, false);

            var cb = ([Event event]) {
                Tooltip.closeAll();
                hints.clearHintCards();

                Tooltip.show(querySelector("#toggle-physics"), "Apply physics to drop blocks", Tooltip.BOTTOM, maxWidth: 300);

                var toggleStream = querySelector("#toggle-physics").onClick.listen((event) {
                    Tooltip.closeAll();
                });

                querySelector("#toggle-physics").onClick.listen((event) {
                    toggleStream.cancel();
                });
            };

            Tooltip.showSimple("Left-click to place a block", 225, 335);

            var bodyStream = querySelector("body").onClick.listen(cb);

            querySelector("body").onClick.listen((event) {
                bodyStream.cancel();
            });
        }
    }

    static void showRunout() {
        if (!storage.containsKey("runout_occured")) {
            Tooltip.show(querySelector(".dynamic"), "Amount of blocks is limited", Tooltip.RIGHT, maxWidth: 300, closeDelay: 1500);
            storage["runout_occured"] = "true";
        }
    }

    static void showRewind() {
        if (!storage.containsKey("apply_fail_occured")) {
            Tooltip.show(querySelector("#toggle-physics"), "Rewind to try again", Tooltip.BOTTOM, maxWidth: 300, callback: () {
                Tooltip.showSimple("To remove the selected block, <b>right-click</b> or <b>press Delete</b>", 200, 225);

                var bodyStream = querySelector("body").onContextMenu.listen((event) {
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
            showingRotation = true;
            Tooltip.showSimple("<b>To rotate the block,</b> use your mouse wheel or buttons Q/E", 100, 285);
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

    static void showHintsTooltip() {
        new Timer(new Duration(seconds: 1), () {
            Tooltip.show(querySelector("#hint"), "If you are in trouble with accomplishing this level, <b>use hints</b>", Tooltip.BOTTOM, maxWidth: 300, xOffset: -90);

            var stream = querySelector("#hint").onClick.listen((event) {
                Tooltip.closeAll();
            });

            querySelector("#hint").onClick.listen((event) {
                stream.cancel();
            });
        });
    }

    static void showZoom() {
        new Timer(new Duration(seconds: 3), () {
            if (manager.states.contains(engine)) {
                Tooltip.show(querySelector("#zoom-out"), "<b>Use zoom</b> for accuracy", Tooltip.BOTTOM, maxWidth: 300, xOffset: -30, xArrowOffset: -25);

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
                Tooltip.show(_static, "Static blocks don't fall when physics applied, and don't conduct energy.", Tooltip.RIGHT, maxWidth: 300, yOffset: 0, yArrowOffset: -3);
            }
        });
    }
}