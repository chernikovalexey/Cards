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

  static Element currentBox; // current box
  static Element progress = querySelector(".tutorial-progress");

  static const String DYNAMIC =
      "Block type. Dynamic conduct energy. Pay attention to the remaining amount.";
  static const String STATIC =
      "Static blocks. They don't fall when physics applied. But, as well, they <b>don't convey the energy</b>.";
  static const String ZOOM =
      "Use two these buttons to zoom camera in and out, accordingly.";
  static const String TOGGLE_PHYSICS =
      "Drop all blocks according to the physical laws, and run the energy flow through the blocks that are connected to the energy cube.";

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

  static void manage(int chapter, int level) {
    if (chapter == 1 && level == 1) {
      showOverview();
    } else if (chapter == 1 && level == 8) {
      showStaticAppear();
    }
  }

  static void showOverview() {
    showing = true;

    fadeBoxIn(progress);

    querySelectorAll(".progress-step").onClick.listen((event) {
      if (event.target.classes.contains("wizard-overview")) {
        enterStep(querySelector("#wizard-overview"), () {
          Tooltip.closeAll();
          RatingShower.unblurGameBox();

          //engine.bcard.b.setTransform(new Vector2(150.0 / GameEngine.scale, 200.0 / GameEngine.scale), engine.bcard.b.angle);

          engine.manuallyControlled = true;
          engine.addCard(150.0 / GameEngine.scale, 200.0 / GameEngine.scale,
              engine.bcard.b.angle);

          engine.bobbin.rewindComplete = () {
            //new Timer(new Duration(milliseconds: 850), () {
              if (engine.manuallyControlled) applyRewindLabelToButton();
            //});
          };

          engine.addOnLevelEndCallback(() {
            //new Timer(new Duration(milliseconds: 850), () {
              if (engine.manuallyControlled) applyPhysicsLabelToButton();
            //});
          });

          applyRewindLabelToButton();
          //EnergySprite to = engine.to.userData as EnergySprite;

          //applyRewindLabelToButton();

          /*Tooltip.show(querySelector(".plus"), ZOOM, Tooltip.BOTTOM, maxWidth:
              300, xOffset: -79, xArrowOffset: 24);
          Tooltip.show(querySelector("#toggle-physics"), TOGGLE_PHYSICS,
              Tooltip.BOTTOM, maxWidth: 300, xOffset: 91);

          int first = Tooltip.opened.first;
          int last = Tooltip.opened.last;
          Tooltip.highlightByIndex(first, {
            'highlighted': [".plus", ".minus"],
            'blurred': ["#graphics", "#toggle-physics", ".show-controls",
                ".dynamic"]
          });
          Tooltip.addCloseListener((int index) {
            if (index == first) {
              Tooltip.removeHighlighting(first, () {
                Tooltip.highlightByIndex(last, {
                  'highlighted': ["#toggle-physics"],
                  'blurred': ["#graphics", ".plus", ".minus", ".show-controls",
                      ".dynamic"]
                });
              });
            } else if (index == last) {
              Tooltip.removeHighlighting(last);
            }
          });*/
        });
      } else if (event.target.classes.contains("wizard-controls")) {
        enterStep(querySelector("#wizard-controls"), () {
          Tooltip.closeAll();

          RatingShower.blurGameBox();
        });
      } else if (event.target.classes.contains("wizard-try")) {
        enterStep(querySelector("#wizard-try"), () {
          engine.removeOnLevelEndCallback();
          engine.bobbin.rewindComplete = null;
          applyPhysicsLabelToButton();
          engine.manuallyControlled = false;

          RatingShower.unblurGameBox();
          Tooltip.show(querySelector(".dynamic"), DYNAMIC, Tooltip.RIGHT,
              maxWidth: 300, yOffset: -9, yArrowOffset: -12);
        });
      }
    });

    querySelector(".wizard-overview").click();
  }

  static void showStaticAppear() {
    Tooltip.show(querySelector(".static"), STATIC, Tooltip.RIGHT, maxWidth: 300,
        yOffset: -9, yArrowOffset: -12);
  }
}
