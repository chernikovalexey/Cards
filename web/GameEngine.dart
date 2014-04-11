import 'dart:html';
import 'dart:math' as Math;
import 'package:box2d/box2d_browser.dart';
import "Input.dart";
import "BoundedCard.dart";

class GameEngine {
  static const double SCALE = 100.0;

  static const double WIDTH = 800.0 / SCALE;

  static const double HEIGHT = 600.0 / SCALE;

  static const double CARD_WIDTH = 0.45;

  static const double CARD_HEIGHT = 0.025;

  static const double ZERO_GRAVITY = 0.0;
<<<<<<< HEAD
  static const double NORMAL_GRAVITY = -10.0;
=======

  static const double NORMAL_GRAVITY = -10.0;

//-9.8 * 2.5;
>>>>>>> 20223d5ccdc46e78472bdae5f4e2819afbb83429

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
    viewport = new CanvasViewportTransform(new Vector2(0.0, 0.0), new Vector2(0.0, HEIGHT));
    viewport.yFlip = true;
    viewport.scale = SCALE;

    debugDraw = new CanvasDraw(viewport, g);

// Have the world draw itself for debugging purposes.
    world.debugDraw = debugDraw;
  }

  void initializeWorld() {
    world = new World(new Vector2(0.0, NORMAL_GRAVITY), true, new DefaultWorldPool());


// Create the ground.
    PolygonShape sd = new PolygonShape();
    sd.setAsBox(WIDTH, HEIGHT * 0.01);

    FixtureDef fd = new FixtureDef();
    fd.shape = sd;
    fd.friction = 1.0;

    BodyDef bd = new BodyDef();
    bd.position = new Vector2(0.0, -HEIGHT * 0.99);

    Body ground = world.createBody(bd);
    ground.createFixture(fd);

    bcard = new BoundedCard(this);
  }

  Body addCard(double x, double y, double angle) {
    PolygonShape cs = new PolygonShape();
    cs.setAsBox(CARD_WIDTH / 2, CARD_HEIGHT / 2);

    FixtureDef fd = new FixtureDef();
    fd.shape = cs;
    fd.density = 1.0;
<<<<<<< HEAD
    fd.friction=0.5;
=======
    fd.friction = 0.99;
>>>>>>> 20223d5ccdc46e78472bdae5f4e2819afbb83429
    fd.restitution = 0.2;

    BodyDef def = new BodyDef();
    def.type = getBodyType(physicsEnabled);
    def.position = new Vector2(x, y);
    def.angularDamping = 10.5;
<<<<<<< HEAD
    //def.linearVelocity = new Vector2(0.0, 2.0);
    def.bullet = true;
=======
//  def.bullet = true;
>>>>>>> 20223d5ccdc46e78472bdae5f4e2819afbb83429
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

    world.step(1.0 / 60.0, 100, 100);
    update(delta);

    g.setFillColorRgb(0, 0, 0);
    g.fillRect(0, 0, 800, 800);

    world.drawDebugData();

    this.lastStepTime = time;
    run();
  }

  void update(num delta) {
    bcard.update();

    if (Input.isMouseClicked && bcard.canPut) {
      addCard(bcard.b.position.x, bcard.b.position.y, bcard.b.angle);
    }

    Input.update();
  }
}
