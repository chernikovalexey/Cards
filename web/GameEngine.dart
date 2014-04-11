import 'dart:html';
import 'package:box2d/box2d_browser.dart';
import "Input.dart";
import "BoundedCard.dart";

class GameEngine {
  static const double WIDTH = 800.0;
  static const double HEIGHT = 600.0;

  static const double CARD_WIDTH = 45.0;
  static const double CARD_HEIGHT = 2.5;

  static const double ZERO_GRAVITY = 0.0;
  static const double NORMAL_GRAVITY = -9.8 * 2.5;

  num lastStepTime = 0;

  bool physicsEnabled = false;

  World world;
  CanvasRenderingContext2D g;
  ViewportTransform viewport;
  DebugDraw debugDraw;
  BoundedCard bcard;

  List<Body> cards = new List<Body>();

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

    FixtureDef fd = new FixtureDef();
    fd.shape = sd;
    fd.friction = 0.99;

    BodyDef bd = new BodyDef();
    bd.position = new Vector2(WIDTH / 2, 5.0);

    Body ground = world.createBody(bd);
    ground.createFixture(fd);

    bcard = new BoundedCard(this);
  }

  Body addCard(double x, double y, double angle) {
    PolygonShape cs = new PolygonShape();
    cs.setAsBox(CARD_WIDTH / 2, CARD_HEIGHT / 2);

    FixtureDef fd = new FixtureDef();
    fd.shape = cs;
    fd.density = 0.05 * CARD_WIDTH * CARD_HEIGHT;
    //fd.friction=0.99;
    //fd.restitution = 0.0001;

    BodyDef def = new BodyDef();
    def.type = getBodyType(physicsEnabled);
    def.position = new Vector2(x, y);
    def.angularDamping = 10.5;
    def.linearVelocity = new Vector2(0.0, -HEIGHT * 4);
    def.bullet = true;
    def.angle = angle;

    Body card = world.createBody(def);
    card.createFixture(fd);

    cards.add(card);
    
    return card;
  }

  int getBodyType(bool activeness) {
    return activeness ? BodyType.DYNAMIC : BodyType.STATIC;
  }

  void togglePhysics(bool active) {
    physicsEnabled = active;
    for (Body body in cards) {
      body.type = getBodyType(active);
    }
  }

  void run() {
    window.animationFrame.then(step);
  }

  void step(num time) {
    num delta = time - this.lastStepTime;

    world.step(1 / 60, 10, 10);
    update(delta);

    g.setFillColorRgb(0, 0, 0);
    g.fillRect(0, 0, 800, 800);

    world.drawDebugData();

    this.lastStepTime = time;
    run();
  }

  void update(num delta) {
    bcard.update();

    if (Input.isMouseClicked) {
      addCard(bcard.b.position.x, bcard.b.position.y, bcard.b.angle);
    }

    Input.update();
  }
}
