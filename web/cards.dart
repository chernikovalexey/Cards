import 'dart:html';
import 'GameEngine.dart';
import 'Input.dart';

CanvasElement canvas;

void main() {
  canvas = (querySelector("#graphics") as CanvasElement);
  CanvasRenderingContext2D g = canvas.getContext('2d');

  canvas.onMouseMove.listen(Input.onMouseMove);
  canvas.onMouseDown.listen(Input.onMouseDown);

  // release the mouse no matter where it currently is
  window.onMouseUp.listen(Input.onMouseUp);
  canvas.onMouseWheel.listen(Input.onMouseWheel);
  canvas.onContextMenu.listen(Input.onContextMenu);

  window.onKeyDown.listen(Input.onKeyDown);
  window.onKeyUp.listen(Input.onKeyUp);

  var r = canvas.getBoundingClientRect();
  Input.canvasX = r.left;
  Input.canvasY = r.top;
  Input.canvasWidth = r.width;
  Input.canvasHeight = r.height;

  // Runs automatically
  GameEngine engine = new GameEngine(g);
  //engine.run();

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

  for (var x in querySelectorAll("input")) x.addEventListener("change", (event)
      => engine.restart(double.parse((querySelector("#density") as InputElement).value
      ), double.parse((querySelector("#friction") as InputElement).value),
      double.parse((querySelector("#restitution") as InputElement).value)));
}
