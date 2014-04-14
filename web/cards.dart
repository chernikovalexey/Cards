import 'dart:html';
import 'GameEngine.dart';
import 'Input.dart';
import 'package:animation/animation.dart';
import 'dart:async';

CanvasElement canvas;
GameEngine engine;

void main() {
  canvas = (querySelector("#graphics") as CanvasElement);
  CanvasRenderingContext2D g = canvas.getContext('2d');

  // Runs automatically
  engine = new GameEngine(g);

  canvas.onMouseMove.listen(Input.onMouseMove);
  canvas.onMouseDown.listen(Input.onMouseDown);

  // release the mouse no matter where it currently is
  window.onMouseUp.listen(Input.onMouseUp);
  canvas.onMouseWheel.listen(Input.onMouseWheel);
  canvas.onContextMenu.listen(Input.onContextMenu);

  window.onKeyDown.listen(Input.onKeyDown);
  window.onKeyUp.listen(Input.onKeyUp);
  window.onResize.listen(updateCanvasPositionAndDimension);
  window.onBeforeUnload.listen((Event event) => engine.saveCurrentProgress());

  updateCanvasPositionAndDimension();

  querySelector('#toggle-physics').addEventListener("click", (event) {
    ButtonElement btn = (event.target as ButtonElement);

    if (!btn.classes.contains("rewind")) {
      btn.text = "Rewind";
      engine.togglePhysics(true);
    } else {
      btn.text = "Apply physics";
      engine.rewind();
    }

    btn.classes.toggle("rewind");
  }, false);
  querySelector("#zoom-in").addEventListener("click", (event) => engine.zoom(
      true));
  querySelector("#zoom-out").addEventListener("click", (event) => engine.zoom(
      false));

  //updateBlockButtons(engine);

  querySelectorAll(".selector").forEach((DivElement el) {
    el.addEventListener("click", (event) {
      bool static = el.classes.contains("static");
      engine.staticBlocksSelected = static;
      updateBlockButtons(engine);
      el.classes.add("current");
    }, false);
  });

  for (var x in querySelectorAll("input")) x.addEventListener("change", (event)
      => engine.restart(double.parse((querySelector("#density") as InputElement).value
      ), double.parse((querySelector("#friction") as InputElement).value),
      double.parse((querySelector("#restitution") as InputElement).value)));
}

void showLevelName(String name) {
  var el = querySelector(".level-name");

  el.innerHtml = name;
  el.style.display = "block";
  el.style.marginTop = "65";

  animate(el, properties: {
    'margin-top': 50,
    'opacity': 1.0,
    'font-size': 24
  }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN_OUT);

  new Timer(new Duration(seconds: 3), () {
    animate(el, properties: {
      'margin-top': -20,
      'opacity': 0.0,
      'font-size': 30
    }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN_OUT);
  });
}

void updateCanvasPositionAndDimension([Event event = null]) {
  if (canvas != null) {
    Rectangle r = canvas.getBoundingClientRect();
    Input.canvasX = r.left;
    Input.canvasY = r.top;
    Input.canvasWidth = r.width;
    Input.canvasHeight = r.height;
  }
}

void applyPhysicsLabelToButton() {
  querySelector("#toggle-physics").text = "Apply physics";
  engine.rewind();
}

void updateBlockButtons(GameEngine engine) {
  querySelectorAll(".selector").forEach((DivElement s) {
    s.classes.remove("current");
  });
  (querySelectorAll(".selector")[engine.staticBlocksSelected ? 0 : 1] as
      DivElement).classes.add("current");

  querySelector(".static .remaining").innerHtml =
      engine.level.current.staticBlocksRemaining.toString();
  querySelector(".dynamic .remaining").innerHtml =
      engine.level.current.dynamicBlocksRemaining.toString();
}
