library engine;

import 'dart:html';
import 'dart:math' as Math;
import 'package:box2d/box2d_browser.dart';

class GameEngine {
  CanvasRenderingContext2D g;

  num time = 0;

  World world = new World(new Vector2(0.0, -9.8), true, new DefaultWorldPool());
  List<Body> bodies = new List<Body>();

  ViewportTransform viewport;
  DebugDraw debugDraw;

  GameEngine(CanvasRenderingContext2D g) {
    this.g = g;
    
    initializeCanvas();
    initializeWorld();
  }

  void initializeCanvas() {
    final extents = new Vector2(800.0 / 2.0, 800.0 / 2.0);
    viewport = new CanvasViewportTransform(extents, extents);
    viewport.scale = 10.0;

    debugDraw = new CanvasDraw(viewport, g);

    // Have the world draw itself for debugging purposes.
    world.debugDraw = debugDraw;
  }

  void initializeWorld() {
    // Create the ground.
    PolygonShape sd = new PolygonShape();
    sd.setAsBox(50.0, 0.4);

    BodyDef bd = new BodyDef();
    bd.position = new Vector2(0.0, 0.0);
    bd.angle = Math.PI / 8;
    Body ground = world.createBody(bd);
    ground.createFixtureFromShape(sd);

    // Create a bouncing ball.
    final bouncingBall = new CircleShape();
    bouncingBall.radius = 5.0;

    final ballFixtureDef = new FixtureDef();
    ballFixtureDef.restitution = 0.7;
    ballFixtureDef.density = 0.05;
    ballFixtureDef.shape = bouncingBall;

    final ballBodyDef = new BodyDef();
    ballBodyDef.linearVelocity = new Vector2(-4.5, -2.0);
    ballBodyDef.position = new Vector2(15.0, 15.0);
    ballBodyDef.type = BodyType.DYNAMIC;
    ballBodyDef.bullet = true;

    final ballBody = world.createBody(ballBodyDef);
    ballBody.createFixture(ballFixtureDef);
  }

  void run() {
    window.animationFrame.then(step);
  }

  void step(num time) {
    num delta = time - this.time;

    const num TIME_STEP = 1 / 60;
    const int VELOCITY_ITERATIONS = 10;
    const int POSITION_ITERATIONS = 10;
    world.step(TIME_STEP, VELOCITY_ITERATIONS, POSITION_ITERATIONS);
    g.clearRect(0, 0, 800, 800);
    world.drawDebugData();

    this.time = time;

    run();
  }
}
