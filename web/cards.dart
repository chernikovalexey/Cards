library cards;

import 'dart:html';
import 'GameEngine.dart';
import "Input.dart";

void main() {
    CanvasElement canvas = (querySelector("#graphics") as CanvasElement);
    CanvasRenderingContext2D g = canvas.getContext('2d');

    window.onMouseMove.listen(Input.onMouseMove);
    window.onMouseDown.listen(Input.onMouseDown);
    window.onMouseUp.listen(Input.onMouseUp);

    var r = canvas.getBoundingClientRect();
    Input.canvasX = r.left;
    Input.canvasY = r.top;
    Input.canvasWidth = r.width;
    Input.canvasHeight = r.height;
    new GameEngine(g).run();
}