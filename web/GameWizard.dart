import 'dart:html';
import "cards.dart";
import 'Tooltip.dart';

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

  static void enterStep(Element box) {
    if (currentBox != box) {
      var callback = () {
        fadeBoxIn(box);
        currentBox = box;
      };

      if (currentBox != null) {
        fadeBoxOut(currentBox, ANIM_TIME, callback);
      } else {
        callback();
      }

      querySelectorAll(".progress-step").forEach((Element el) {
        el.classes.remove("active-step");
      });
      querySelector(".tutorial-progress ." + box.id).classes.add("active-step");
    }
  }

  static void finish() {
    showing = false;
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
    enterStep(querySelector("#wizard-overview"));

    Tooltip.show(querySelector(".plus"), ZOOM, Tooltip.BOTTOM, maxWidth: 300,
        xOffset: -79, xArrowOffset: 24);
    Tooltip.show(querySelector("#toggle-physics"), TOGGLE_PHYSICS,
        Tooltip.BOTTOM, maxWidth: 300, xOffset: 91);

    Tooltip.highlightByIndex(0, {
      'highlighted': [".plus", ".minus"],
      'blurred': ["#graphics", "#toggle-physics", ".show-controls", ".dynamic"]
    });
    Tooltip.addCloseListener((int index) {
      if (index == 0) {
        Tooltip.removeHighlighting(0);
        Tooltip.highlightByIndex(1, {
          'highlighted': ["#toggle-physics"],
          'blurred': ["#graphics", ".plus", ".minus", ".show-controls",
              ".dynamic"]
        });
      } else if (index == 1) {
        Tooltip.removeHighlighting(1);
      }
    });

    querySelectorAll(".progress-step").onClick.listen((event) {
      if (event.target.classes.contains("wizard-overview")) {
        enterStep(querySelector("#wizard-overview"));
      } else if (event.target.classes.contains("wizard-controls")) {
        enterStep(querySelector("#wizard-controls"));
      } else if (event.target.classes.contains("wizard-try")) {
        enterStep(querySelector("#wizard-try"));
      }
    });
  }

  static void showStaticAppear() {
    Tooltip.show(querySelector(".static"), STATIC, Tooltip.RIGHT, maxWidth: 300,
        yOffset: -9, yArrowOffset: -12);
  }
}
