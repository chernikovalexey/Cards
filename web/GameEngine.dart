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
import 'StateManager.dart';
import 'dart:js';
import "Color4.dart";
import "SuperCanvasDraw.dart";
import "StarManager.dart";

/*class HistoryState {
  static const ADD = 1;
  static const REMOVE = 2;

  int action;
  List<Body> affectedCards = new List<Body>();
}*/

class GameEngine extends State {
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
  static double get ENERGY_BLOCK_WIDTH => NENERGY_BLOCK_WIDTH / NSCALE;
  static double get ENERGY_BLOCK_HEIGHT => NENERGY_BLOCK_HEIGHT / NSCALE;
  static double scale = NSCALE;

  num lastStepTime = 0;
  bool physicsEnabled = false;
  bool isPaused = false;
  bool ready = false;

  World world;
  DefaultWorldPool pool;
  CardContactListener contactListener;
  CanvasRenderingContext2D g;
  ViewportTransform viewport;
  SuperCanvasDraw debugDraw;
  BoundedCard bcard;
  Bobbin bobbin;
  Camera camera;
  Traverser traverser;
  Level level;

  Body from, to;

  List<Body> cards = new List<Body>();
  List<Body> recentlyRemovedCards = new List<Body>();
  List<int> stars;
  List levels;
  
  bool staticBlocksSelected = false;
  bool isRewinding = false;

  double cardDensity = 0.1, cardFriction = 0.1, cardRestitution = 0.00;
  double currentZoom = 1.0;

  GameEngine(CanvasRenderingContext2D g) {
    this.g = g;
    camera = new Camera(this);
  }

  @override

  void start([Map params]) {
    if (params != null) {
      initializeWorld();
      initializeCanvas();

      level = new Level(() {
        ready = true;
      }, params["chapter"], this);
    }
  }

  void initializeCanvas() {
    viewport = new CanvasViewportTransform(new Vector2(0.0, 0.0), new Vector2(
        0.0, HEIGHT));
    viewport.scale = scale;

    debugDraw = new SuperCanvasDraw(viewport, g);
  }

  void initializeWorld() {
    pool = new DefaultWorldPool();

    this.contactListener = new CardContactListener(this);
    this.world = new World(new Vector2(0.0, GRAVITY), true, pool);

    world.contactListener = contactListener;

    this.bcard = new BoundedCard(this);
    this.traverser = new Traverser(this);

    this.bobbin = new Bobbin(() {
      traverser.reset();
      if (from.contactList != null) {
        traverser.traverseEdges(from.contactList);
        print("traverser.hasPath: " + traverser.hasPath.toString());
      }
      if (!traverser.hasPath) {
        for (Body card in cards) {

          if (traverser.checkEnergyConnection(card)) {

            traverser.traverseEdges(card.contactList);
          }
        }
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

  Body createMultiShape(List<Vector2> points) {
    PolygonShape sd = new PolygonShape();
    sd.setFrom(points, points.length);

    FixtureDef fd = new FixtureDef();
    fd.shape = sd;
    fd.friction = 0.7;

    BodyDef bd = new BodyDef();

    Body body = world.createBody(bd);
    body.createFixture(fd);

    return body;
  }

  bool canPut([bool ignorePhysics = false]) {
    return !Input.keys['z'].down && !Input.isAltDown &&
        !Input.keys['space'].down && Input.isMouseLeftClicked &&
        contactListener.contactingBodies.isEmpty && (ignorePhysics || !physicsEnabled);
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

    EnergySprite sprite = Sprite.card(world);
    sprite.isStatic = isStatic;
    sprite.energySupport = (!isStatic || sub != null);
    if (isStatic) {
      sprite.color = new Color4.fromRGB(217, 214, 179);
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

  @override

  void update(num delta) {
    if (!ready || isPaused) {
      return;
    }

    if (Input.keys['esc'].clicked) {
      RatingShower.pause(this);
    }
    RatingShower.wasJustPaused = false;

    world.step(1.0 / 60, 10, 10);

    setCanvasCursor('none');

    //if (Input.keys['p'].clicked) {
    //previousLevel();
    //}

    bcard.update();
    camera.update(delta);

    if (physicsEnabled) {
      bobbin.enterFrame(cards);
    }

    if (isRewinding) {
      isRewinding = bobbin.previousFrame(cards);
      if (!isRewinding) {
        bobbin.erase();
        if (bobbin.rewindComplete != null) bobbin.rewindComplete();
      }
    }

    if (level.current != null && ((staticBlocksSelected &&
        level.current.staticBlocksRemaining > 0) || (!staticBlocksSelected &&
        level.current.dynamicBlocksRemaining > 0))) {
      if (canPut()) {
        recentlyRemovedCards.clear();
        addCard(bcard.b.position.x, bcard.b.position.y, bcard.b.angle,
            staticBlocksSelected);
      } else if (canPut(true)) {
        blinkPhysicsButton();
      }
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
      staticBlocksSelected = false;
      updateBlockButtons(this);
    }
    if (Input.keys['2'].clicked && level.current.staticBlocksRemaining > 0) {
      staticBlocksSelected = true;
      updateBlockButtons(this);
    }

    if (contactListener.contactingBodies.isNotEmpty && Input.isMouseRightClicked
        && !isRewinding) {
      List<Body> cardsToRemove = new List<Body>();
      cardsToRemove.addAll(contactListener.contactingBodies);
      contactListener.contactingBodies.clear();
      for (Body contacting in cardsToRemove) {
        if (cards.contains(contacting)) {
          removeCard(contacting);
        }
      }
    } else if (Input.keys['ctrl'].down && Input.keys['z'].clicked) {
      for (Body card in recentlyRemovedCards) {
        addCard(card.position.x, card.position.y, card.angle, (card.userData as
            EnergySprite).isStatic);
      }
      recentlyRemovedCards.clear();
    }

    for (Body c in cards) {
      (c.userData as EnergySprite).update(this);
    }

    if (to != null) {
      EnergySprite sprite = to.userData as EnergySprite;
      if (physicsEnabled) {

        sprite.update(this);
        if (sprite.isFull() && level.current != null) {
          saveCurrentProgress();
          int or = level.current.rating;
          int nr = level.current.getRating();


          StarManager.updateResult(level.chapter, nr - or);
          RatingShower.show(this, nr);
        }
      } else {
        sprite.deactivate();
      }
    }

    Input.update();
  }

  // saves the state of the current level

  void saveCurrentProgress() {

    // No sense to save empty states, indeed
    if (ready && !cards.isEmpty && level.current != null) {
      window.localStorage['level_' + level.chapter.toString() + '_' +
          level.current.index.toString()] = LevelSerializer.toJSON(cards, bobbin.list,
          physicsEnabled);
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

  @override

  void render() {
    if (ready) {
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
    recentlyRemovedCards.add(c);

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
      }
      camera.checkTarget();
      //camera.updateEngine(newZoom);
    }

    camera.beginZoom(newZoom, currentZoom);
    currentZoom = newZoom;
  }

  void clear() {
    window.localStorage.remove("level_" + level.chapter.toString() + "_" +
        (level.current.index + 1).toString());
    applyPhysicsLabelToButton();
    bobbin.erase();
    List<Body> _cards = new List<Body>();
    _cards.addAll(cards);
    for (Body b in _cards) {
      removeCard(b);
    }
  }
}
