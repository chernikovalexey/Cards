import 'dart:html';
import "cards.dart";
import 'Tooltip.dart';
import 'dart:async';

class GameWizard {
  static Element box = querySelector("#game-wizard");
  static Element progress = querySelector(".tutorial-progress");

  static const String DYNAMIC =
      "The type of block to put. Pay attention to the amount of blocks remaining.";
  static const String ZOOM =
      "Use two these buttons to zoom camera in and out, accordingly.";
  static const String TOGGLE_PHYSICS =
      "Drop all blocks according to the physical laws, and run the energy flow through the blocks that are connected to the energy cube.";

  static bool showing = false;

  static void show() {
    showing = true;

    fadeBoxIn(progress);
    fadeBoxIn(box);

    //Tooltip.show(querySelector(".dynamic"), DYNAMIC, Tooltip.BOTTOM, 300, 121);
    Tooltip.show(querySelector(".plus"), ZOOM, Tooltip.BOTTOM, 300, -79, 24);
    Tooltip.show(querySelector("#toggle-physics"), TOGGLE_PHYSICS,
        Tooltip.BOTTOM, 350, 115);

    List els = [{
        'highlighted': [".plus", ".minus"],
        'blurred': ["#graphics", "#toggle-physics", ".show-controls",
            ".dynamic"]
      }, {
        'highlighted': ["#toggle-physics"],
        'blurred': ["#graphics", ".plus", ".minus", ".show-controls",
            ".dynamic"]
      }];

    Tooltip.highlightByIndex(0, els[0]);
    Tooltip.addCloseListener((int index) {
      if (index == 0) {
        Tooltip.removeHighlighting(0, els[0]);
        Tooltip.highlightByIndex(1, els[1]);
      } else if (index == 1) {
        Tooltip.removeHighlighting(1, els[1]);
      }
    });

    var speed = 175;
    var controlsBox = querySelector("#controls");

    querySelector(".show-controls").addEventListener("click", (event) {
      fadeBoxOut(box, speed, () {
        fadeBoxIn(controlsBox, speed);
        nextStep();
      });
    }, false);

    querySelector(".try-button").addEventListener("click", (event) {
      fadeBoxOut(controlsBox, speed, () {
        Tooltip.show(querySelector(".dynamic"), DYNAMIC, Tooltip.RIGHT, 300);
      });
      nextStep();
    }, false);

    querySelectorAll(".progress-step").onClick.listen((event) {
      if (event.target.classes.contains("overview")) {

      }
    });
  }

  static void finish() {
    showing = false;
  }

  static void nextStep() {
    Element active = querySelector(".active-step");
    active.classes.remove("active-step");
    active.nextElementSibling.classes.add("active-step");
  }

  static void skip(Event event) {
    fadeBoxOut(box);
    Tooltip.closeAll();
  }
}
