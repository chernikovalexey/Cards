import 'dart:html';
import 'dart:math' as Math;
import 'package:box2d/box2d_browser.dart';
import 'cards.dart';
import "Input.dart";
import "BoundedCard.dart";
import "Bobbin.dart";
import "CardContactListener.dart";
import 'Camera.dart';
import 'Sprite.dart';
import 'Traverser.dart';
import 'EnergySprite.dart';
import 'dart:async';
import 'RatingShower.dart';
import "Level.dart";
import 'SubLevel.dart';
import 'LevelComplete.dart';
import 'LevelSerializer.dart';
import 'ParallaxManager.dart';

class GameEngine {
  static const double NSCALE = 85.0;
  static double get NWIDTH => Input.canvasWidth;
  static double get NHEIGHT => Input.canvasHeight;
  static const double NCARD_WIDTH = 45.0;
  static const double NCARD_HEIGHT = 2.5;
  static const double NENERGY_BLOCK_WIDTH = 35.0;
  static const double NENERGY_BLOCK_HEIGHT = NENERGY_BLOCK_WIDTH;
  static const double GRAVITY = -10.0;

  static double get WIDTH => NWIDTH / scale;
  static double get HEIGHT => NHEIGHT / scale;
  static double get CARD_WIDTH => NCARD_WIDTH / scale;
  static double get CARD_HEIGHT => NCARD_HEIGHT / scale;
  static double get ENERGY_BLOCK_WIDTH => NENERGY_BLOCK_WIDTH / scale;
  static double get ENERGY_BLOCK_HEIGHT => NENERGY_BLOCK_HEIGHT / scale;

  static double scale = NSCALE;

  num lastStepTime = 0;
  bool physicsEnabled = false;
  bool isPaused = false;

  World world;
  CardContactListener contactListener;
  CanvasRenderingContext2D g;
  ViewportTransform viewport;
  DebugDraw debugDraw;
  BoundedCard bcard;
  Bobbin bobbin;
  Camera camera;
  Traverser traverser;

  Body from, to;

  List<Body> cards = new List<Body>();

  List levels;
  DefaultWorldPool pool;
  bool staticBlocksSelected = false;

  bool isRewinding = false;
  double cardDensity = 0.1, cardFriction = 0.1, cardRestitution = 0.00;
  double currentZoom = 1.0;
  List<int> stars;
  Level level;

  GameEngine(CanvasRenderingContext2D g) {
    this.g = g;
    camera = new Camera(this);
  }

  void start() {
    initializeWorld();
    initializeCanvas();

    level = new Level(run, this);
  }

  void initializeCanvas() {
    viewport = new CanvasViewportTransform(new Vector2(0.0, 0.0), new Vector2(
        0.0, HEIGHT));
    viewport.scale = scale;

    debugDraw = new CanvasDraw(viewport, g);
    world.debugDraw = debugDraw;
  }

  void initializeWorld() {
    pool = new DefaultWorldPool();

    this.contactListener = new CardContactListener(this);
    this.world = new World(new Vector2(0.0, GRAVITY), true, pool);

    world.contactListener = contactListener;

    this.bcard = new BoundedCard(this);
    this.traverser = new Traverser(this);

    this.bobbin = new Bobbin(() {
      if (from.contactList != null) {
        Stopwatch stopwatch = new Stopwatch();
        stopwatch.start();

        traverser.reset();
        traverser.traverseEdges(from.contactList);
        print(traverser.hasPath);

        stopwatch.stop();
        print("Elapsed: " + stopwatch.elapsedMilliseconds.toString());
        print("Checked: " + traverser.traversed.length.toString());
      }
    });
  }

  void setCanvasCursor(String cursor) {
    canvas.style.cursor = cursor;
  }

  FixtureDef createHelperFixture(double w, double h) {
    FixtureDef fd = new FixtureDef();
    fd.isSensor = true;
    PolygonShape s = new PolygonShape();
    s.setAsBox(w / 2 + .01, h / 2 + .01);
    fd.shape = s;
    fd.userData = false;

    return fd;
  }

  Body createPolygonShape(double x, double y, double width, double height) {
    PolygonShape sd = new PolygonShape();
    sd.setAsBox(width / 2, height / 2);

    FixtureDef fd = new FixtureDef();
    fd.shape = sd;
    fd.friction = 0.7;

    BodyDef bd = new BodyDef();
    bd.position = new Vector2(x + width / 2, y + height / 2);

    Body body = world.createBody(bd);
    body.createFixture(fd);
    body.createFixture(createHelperFixture(width, height));


    return body;
  }

  bool canPut() {
    return !Input.keys['z'].down && !Input.isAltDown &&
        !Input.keys['space'].down && Input.isMouseLeftClicked &&
        contactListener.contactingBodies.isEmpty && !physicsEnabled;
  }

  Body addCard(double x, double y, double angle, [bool isStatic =
      false, SubLevel sub = null]) {
    PolygonShape cs = new PolygonShape();
    cs.setAsBox(CARD_WIDTH / 2 * currentZoom, CARD_HEIGHT / 2 * currentZoom);

    FixtureDef fd = new FixtureDef();
    fd.shape = cs;
    fd.density = cardDensity;
    fd.friction = cardFriction;
    fd.restitution = cardRestitution;

    BodyDef def = new BodyDef();
    def.type = getBodyType(physicsEnabled);
    def.position = new Vector2(x, y);
    def.angularDamping = 10.5;
    def.bullet = true;
    def.angle = angle;

    Body card = world.createBody(def);
    card.createFixture(fd);
    card.createFixture(createHelperFixture(CARD_WIDTH, CARD_HEIGHT));

    if (sub != null) {
      isStatic = true;
    }

    EnergySprite sprite = Sprite.card(world);
    sprite.isStatic = isStatic;
    sprite.energySupport = !isStatic;
    if (isStatic) {
      sprite.color = new Color3.fromRGB(217, 214, 179);
    }

    card.userData = sprite;

    if (sub == null) {
      sub = level.current;
      cards.add(card);
    } else {
      sub.cards.add(card);
    }

    if (isStatic) {
      --sub.staticBlocksRemaining;
    } else {
      --sub.dynamicBlocksRemaining;
    }
    updateBlockButtons(this);

    return card;
  }

  int getBodyType(bool activeness, [bool isStatic = false]) {
    return activeness && !isStatic ? BodyType.DYNAMIC : BodyType.STATIC;
  }

  void togglePhysics(bool active) {
    physicsEnabled = active;
    if (physicsEnabled) {
      bobbin.erase();
    } else {
      (to.userData as Sprite).deactivate();
    }
    for (Body body in cards) {
      body.type = getBodyType(active, (body.userData as EnergySprite).isStatic);
      if (!physicsEnabled) (body.userData as Sprite).deactivate();
    }
  }

  void toggleBoundedCard(bool visible) {
    (bcard.b.userData as Sprite).isHidden = !visible;
  }

  void run() {
    window.animationFrame.then(step);
  }

  void step(num time) {
    if (!isPaused) {
      num delta = time - this.lastStepTime;

      world.step(1.0 / 60, 10, 10);
      update(delta);

      g.setFillColorRgb(0, 0, 0);
      g.fillRect(0, 0, NWIDTH, NHEIGHT);
      render();
      this.lastStepTime = time;
    }

    run();
  }

  void update(num delta) {
    if (level == null) {
      return;
    }

    setCanvasCursor('none');

    if (Input.keys['p'].clicked) {
      print("prev");
      previousLevel();
    }

    bcard.update();
    camera.update(delta);

    if (physicsEnabled) {
      bobbin.enterFrame(cards);
    }

    if (isRewinding) {
      isRewinding = bobbin.previousFrame(cards);
      if (!isRewinding) bobbin.erase();
    }

    if (canPut() && (staticBlocksSelected && level.current.staticBlocksRemaining
        > 0 || level.current.dynamicBlocksRemaining > 0)) {

      addCard(bcard.b.position.x, bcard.b.position.y, bcard.b.angle,
          staticBlocksSelected);
    }

    if (Input.keys['z'].down && !Input.isAltDown) {
      setCanvasCursor('-webkit-zoom-in');
      toggleBoundedCard(false);
      if (Input.isMouseLeftClicked) zoom(true, true);
    }
    if (Input.isAltDown) {
      setCanvasCursor('-webkit-zoom-out');
      toggleBoundedCard(false);
      if (Input.isMouseLeftClicked) zoom(false, true);
    }
    if (Input.keys['1'].clicked) {
      staticBlocksSelected = true;
      updateBlockButtons(this);
    }
    if (Input.keys['2'].clicked) {
      staticBlocksSelected = false;
      updateBlockButtons(this);
    }

    if (contactListener.contactingBodies.isNotEmpty && Input.isMouseRightClicked
        && !isRewinding) {
      List<Body> cardsToDelete = new List<Body>();
      cardsToDelete.addAll(contactListener.contactingBodies);
      contactListener.contactingBodies.clear();
      for (Body contacting in cardsToDelete) {
        if (cards.contains(contacting)) {
          removeCard(contacting);
        }
      }
    }

    for (Body c in cards) {
      (c.userData as EnergySprite).update(this);
    }

    if (to != null) {
      EnergySprite sprite = to.userData as EnergySprite;
      if (physicsEnabled) {

        sprite.update(this);
        if (sprite.isFull()) {
          saveCurrentProgress();
          RatingShower.show(this, level.current.getRating());
        }
      } else {
        sprite.deactivate();
      }
    }

    Input.update();
  }

  // saves the state of the current level
  void saveCurrentProgress() {
    if (level != null) {
      window.localStorage['level_' + level.current.index.toString()] =
          LevelSerializer.toJSON(cards, bobbin.list, physicsEnabled);
    }
  }

  void previousLevel() {
    level.previous();
  }

  void restartLevel() {
    applyPhysicsLabelToButton();
    //rewind();

    (to.userData as EnergySprite).energy = 0.0;
  }

  void nextLevel() {
    if (level.hasNext()) {
      level.current.finish();
      level.next();
    }
  }

  void render() {
    if (level != null) {
      Body b = world.bodyList;
      while (b != null) {
        if (b.userData != null) (b.userData as Sprite).render(debugDraw, b);
        b = b.next;
      }
    }
  }

  void restart(double d, double f, double r) {
    cardDensity = d;
    cardRestitution = r;
    cardFriction = f;

    for (var x in cards) {
      world.destroyBody(x);
    }
    cards = new List<Body>();

    for (int i = 0; i < 13; i++) {
      double x = i * 0.8;
      double y = -i * 0.8;
      addCard(x, y, 0.0);
    }

    togglePhysics(true);
  }

  void rewind() {
    togglePhysics(false);
    isRewinding = true;
  }

  void removeCard(Body c) {
    world.destroyBody(c);
    cards.remove(c);

    EnergySprite sprite = c.userData as EnergySprite;
    if (sprite.isStatic) {
      ++level.current.staticBlocksRemaining;
    } else {
      ++level.current.dynamicBlocksRemaining;
    }
    updateBlockButtons(this);
  }

  void zoom(bool zoomIn, [bool onMouse = false]) {
    double newZoom;

    if (zoomIn) {
      newZoom = currentZoom < 3 ? currentZoom + 0.2 : currentZoom;
    } else {
      newZoom = currentZoom >= 1.2 ? currentZoom - 0.2 : currentZoom;
    }

    if (newZoom != currentZoom) {
      if (onMouse) {
        camera.mTargetX = Input.mouseX - WIDTH / 2;
        camera.mTargetY = Input.mouseY + HEIGHT / 2;
      } else {
        if (zoomIn) {
          camera.mTargetX += WIDTH / 10;
          camera.mTargetY += HEIGHT / 10;
        } else {
          camera.mTargetX -= WIDTH / 10;
          camera.mTargetY -= HEIGHT / 10;
        }
      }

      camera.checkTarget();
      //camera.updateEngine(newZoom);
    }

    camera.beginZoom(newZoom, currentZoom);
    currentZoom = newZoom;
  }

  void clear() {
    bobbin.erase();
    List<Body> _cards = new List<Body>();
    _cards.addAll(cards);
    for (Body b in _cards) {
      removeCard(b);
    }
  }
}
