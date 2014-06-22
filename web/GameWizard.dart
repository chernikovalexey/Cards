import 'dart:html';
import "cards.dart";
import 'Tooltip.dart';
import 'dart:async';
import 'RatingShower.dart';

class GameWizard {
  static const int ANIM_TIME = 175;

  static Element currentBox; // current box
  static Element progress = querySelector(".tutorial-progress");

  static const String DYNAMIC =
      "The type of block to put. Pay attention to the amount of blocks remaining.<br><br>Dynamic blocks convey energy and fall when physics applied.";
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
    
    if(currentBox!=null) {
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

          Tooltip.show(querySelector(".plus"), ZOOM, Tooltip.BOTTOM, maxWidth:
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
          });
        });
      } else if (event.target.classes.contains("wizard-controls")) {
        enterStep(querySelector("#wizard-controls"), () {
          Tooltip.closeAll();
          
          RatingShower.blurGameBox();
        });
      } else if (event.target.classes.contains("wizard-try")) {
        enterStep(querySelector("#wizard-try"), () {
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
