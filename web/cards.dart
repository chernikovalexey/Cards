import 'dart:html';
import 'GameEngine.dart';
import 'Input.dart';

void main() {
  CanvasElement canvas = (querySelector("#graphics") as CanvasElement);
  CanvasRenderingContext2D g = canvas.getContext('2d');

  canvas.onMouseMove.listen(Input.onMouseMove);
  canvas.onMouseDown.listen(Input.onMouseDown);
  canvas.onMouseUp.listen(Input.onMouseUp);
  canvas.onMouseWheel.listen(Input.onMouseWheel);
  canvas.onContextMenu.listen(Input.onContextMenu);

  var r = canvas.getBoundingClientRect();
  Input.canvasX = r.left;
  Input.canvasY = r.top;
  Input.canvasWidth = r.width;
  Input.canvasHeight = r.height;

  GameEngine engine = new GameEngine(g);
  engine.run();

  querySelector('#apply-physics').addEventListener("click", (event) =>
      engine.togglePhysics(true), false);
  querySelector('#disable-physics').addEventListener("click", (event) =>
      engine.togglePhysics(false), false);
}
