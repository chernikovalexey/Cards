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

    static Element currentBox;

    // current box
    static Element progress = querySelector(".tutorial-progress");

    static const String DYNAMIC = "Block type. Dynamic conduct energy. Pay attention to the remaining amount.";
    static const String STATIC = "Static blocks. They don't fall when physics applied. But, as well, they <b>don't convey the energy</b>.";
    static const String ZOOM = "Use two these buttons to zoom camera in and out, accordingly.";
    static const String TOGGLE_PHYSICS = "Apply physics to drop blocks";

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

            querySelectorAll(".progress-step").forEach((Element el) {
                el.classes.remove("active-step");
            });
            querySelector(".tutorial-progress ." + box.id).classes.add("active-step");
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
            if (event.target.classes.contains("wizard-overview")) {
                /*enterStep(querySelector("#wizard-overview"), () {
                    Tooltip.closeAll();
                    RatingShower.unblurGameBox();

                    engine.manuallyControlled = true;
              engine.clear();
              engine.addCard(150.0 / GameEngine.scale, 200.0 / GameEngine.scale,
                  engine.bcard.b.angle);

              int delay = 850;
              bool rEnd = false;

              engine.bobbin.rewindComplete = () {
                if (!rEnd) {
                  rEnd = true;

                  new Timer(new Duration(milliseconds: delay), () {
                    if (engine.manuallyControlled) {
                      applyRewindLabelToButton();
                    }
                  });
                }
              };

              engine.addOnLevelEndCallback(() {
                rEnd = false;
                new Timer(new Duration(milliseconds: delay), () {
                  if (engine.manuallyControlled) {
                    applyPhysicsLabelToButton();
                  }
                });
              });

              applyRewindLabelToButton();

                    Tooltip.show(querySelector("#toggle-physics"), TOGGLE_PHYSICS, Tooltip.BOTTOM, maxWidth: 300);
                });*/
            } else if (event.target.classes.contains("wizard-controls")) {
                enterStep(querySelector("#wizard-controls"), () {
                    Tooltip.closeAll();
                    RatingShower.blurGameBox();
                });
            } else if (event.target.classes.contains("wizard-try")) {
                enterStep(querySelector("#wizard-try"), () {

                    // Show tooltip just in case player is in tutorial
                    // Otherwise, just fade the screen out
                    if (showing) {
                        //engine.removeOnLevelEndCallback();
                        //engine.bobbin.rewindComplete = null;
                        //applyPhysicsLabelToButton();
                        //engine.manuallyControlled = false;

                        Tooltip.show(querySelector(".dynamic"), DYNAMIC, Tooltip.RIGHT, maxWidth: 300, yOffset: -9, yArrowOffset: -12);
                    }

                    RatingShower.unblurGameBox();
                });
            }
        });
    }

    static void manage(int chapter, int level) {
        if (chapter == 1 && level == 1) {
            showOverview();
        } else if (chapter == 1 && level == 3) {
            showHintsTooltip();
        } else if (chapter == 1 && level == 8) {
            showStaticAppear();
        }
    }

    static void showOverview() {
        showing = true;

        hints.addHintCard(1.671, 2.5, 0.0, 1.0, false);

        Tooltip.showSimple("Left-click to place a block", 225, 335);

        var bodyStream = querySelector("body").onClick.listen((event) {
            Tooltip.closeAll();

            Tooltip.show(querySelector("#toggle-physics"), TOGGLE_PHYSICS, Tooltip.BOTTOM, maxWidth: 300);

            var toggleStream = querySelector("#toggle-physics").onClick.listen((event) {
                Tooltip.closeAll();
                hints.clearHintCards();
            });

            querySelector("#toggle-physics").onClick.listen((event) {
                toggleStream.cancel();
            });
        });

        querySelector("body").onClick.listen((event) {
            bodyStream.cancel();
        });
    }

    static void showHintsTooltip() {
        new Timer(new Duration(seconds: 1), () {
            engine.bobbin.rewindComplete = null;
            Tooltip.show(querySelector("#hint"), "If you are in trouble with accomplishing this level, <b>use hints</b>", Tooltip.BOTTOM, maxWidth: 300, xOffset: -90);
        });
    }

    static void showStaticAppear() {
        Tooltip.show(querySelector(".static"), STATIC, Tooltip.RIGHT, maxWidth: 300, yOffset: -9, yArrowOffset: -12);
    }
}
