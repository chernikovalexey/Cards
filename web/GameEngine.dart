library engine;

import 'dart:html';
import 'dart:math' as Math;
import 'package:box2d/box2d_browser.dart';
import "Input.dart";
import "BoundedCard.dart";

class GameEngine {
  static const double WIDTH = 800.0;
  static const double HEIGHT = 600.0;

  static const double CARD_WIDTH = 45.0;
  static const double CARD_HEIGHT = 2.5;

  static const double ZERO_GRAVITY = 0.0;
  static const double NORMAL_GRAVITY = -9.8;

  num lastStepTime = 0;

  World world;
  CanvasRenderingContext2D g;
  ViewportTransform viewport;
  DebugDraw debugDraw;
  BoundedCard card;

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
    sd.setAsBox(WIDTH / 2, 10.0 / 2);

    BodyDef bd = new BodyDef();
    bd.position = new Vector2(WIDTH / 2, 5.0);

    Body ground = world.createBody(bd);
    ground.createFixtureFromShape(sd);

    addCard(40.0, 120.0, Math.PI / 8);
    card = new BoundedCard(this);
  }

  void addCard(double x, double y, double angle) {
    PolygonShape cs = new PolygonShape();
    cs.setAsBox(CARD_WIDTH / 2, CARD_HEIGHT / 2);

    FixtureDef fd = new FixtureDef();
    fd.shape = cs;
    fd.density = 0.025 / CARD_WIDTH * CARD_HEIGHT;
    fd.restitution = 0.1;

    BodyDef def = new BodyDef();
    def.type = BodyType.DYNAMIC;
    def.position = new Vector2(x, y);
    def.linearVelocity = new Vector2(0.0, -100.0);
    def.angle = angle;

    Body card = world.createBody(def);
    card.createFixture(fd);

    bodies.add(card);
  }

  void run() {
    window.animationFrame.then(step);
  }

  void step(num time) {
    num delta = time - this.lastStepTime;

    update(delta);
    world.step(1 / 60, 10, 10);

    g.setFillColorRgb(0, 0, 0);
    g.fillRect(0, 0, 800, 800);

    world.drawDebugData();

    this.lastStepTime = time;

    run();
  }

  void update(num delta) {
    card.update();

    if(Input.isMouseClicked) {
      addCard(Input.mouseX, Input.mouseY, 0.0);      
    }
  }
}
