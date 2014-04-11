library cards;

import 'dart:html';
import 'GameEngine.dart';

void main() {
    CanvasRenderingContext2D g = (querySelector("#graphics") as CanvasElement).getContext('2d');
    new GameEngine(g).run();
}