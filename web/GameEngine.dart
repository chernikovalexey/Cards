library engine;

import 'dart:html';
import 'dart:math' as Math;
import 'package:box2d/box2d_browser.dart';

class GameEngine {
  static const double WIDTH = 800.0;
  static const double HEIGHT = 600.0;

  static const double ZERO_GRAVITY = 0.0;
  static const double NORMAL_GRAVITY = -9.8;

  num lastStepTime = 0;

  World world;
  CanvasRenderingContext2D g;
  ViewportTransform viewport;
  DebugDraw debugDraw;

  List<Body> bodies = new List<Body>();

  GameEngine(CanvasRenderingContext2D g) {
    this.g = g;

    initializeWorld();
    initializeCanvas();
  }

  void initializeCanvas() {
    viewport = new CanvasViewportTransform(new Vector2(0.0, 0.0), new Vector2(
        0.0, HEIGHT));
    viewport.yFlip = true;
    viewport.scale = 1.0;

    debugDraw = new CanvasDraw(viewport, g);

    // Have the world draw itself for debugging purposes.
    world.debugDraw = debugDraw;
  }

  void initializeWorld() {
    world = new World(new Vector2(0.0, NORMAL_GRAVITY), true,
        new DefaultWorldPool());

    // Create the ground.
    PolygonShape sd = new PolygonShape();
    sd.setAsBox(20.0, 20.0 / 2);

    BodyDef bd = new BodyDef();
    bd.position = new Vector2(100.0, 20.0);
    Body ground = world.createBody(bd);
    ground.createFixtureFromShape(sd);

    addCard(-20, 40, Math.PI / 8);
  }

  void addCard(num x, num y, num angle) {
    PolygonShape card = new PolygonShape();
  }

  void run() {
    window.animationFrame.then(step);
  }

  void step(num time) {
    num delta = time - this.lastStepTime;

    world.step(1 / 60, 10, 10);

    g.setFillColorRgb(0, 0, 0);
    g.fillRect(0, 0, 800, 800);

    world.drawDebugData();

    this.lastStepTime = time;

    run();
  }
}
