import "dart:html";
import "Bobbin.dart";
import 'package:box2d/box2d_browser.dart';
import "GameEngine.dart";
import "Sprite.dart";
import 'cards.dart';
import 'Traverser.dart';
import 'EnergySprite.dart';

class SubLevel {
  String name;

  List frames = new List();
  List cards = new List();
  List<Body> obstacles = new List<Body>();
  List stars;

  GameEngine e;

  Object fSprite, tSprite;
  Object levelData;

  Function levelApplied;

  double x, y, w, h;
  int rating = 0;
  int index;
  int staticBlocksRemaining;
  int dynamicBlocksRemaining;

  Body from;
  Body to;

  SubLevel(GameEngine e, Map l, int index) {
    this.index = index;
    this.e = e;
    this.name = l["name"];
    levelData = l;
    x = l['x'].toDouble() / GameEngine.NSCALE;
    y = l['y'].toDouble() / GameEngine.NSCALE;
    w = l['width'].toDouble() / GameEngine.NSCALE;
    h = l['height'].toDouble() / GameEngine.NSCALE;

    this.staticBlocksRemaining = l["blocks"][0];
    this.dynamicBlocksRemaining = l["blocks"][1];
    this.stars = l['stars'];

    double boundsOffset = 0.0;
    if (index > 1) {
      x += e.to.position.x - GameEngine.ENERGY_BLOCK_WIDTH / 2;
      y += e.to.position.y - GameEngine.ENERGY_BLOCK_HEIGHT / 2;
      this.from = e.to;
      this.from.userData = Sprite.from(e.world);
      //boundsOffset = x - (to.position.x - l["from"]["offset"].toDouble() / GameEngine.scale;);
    } else {
      this.from = e.createPolygonShape(l["from"]["x"].toDouble() /
          GameEngine.NSCALE, l["from"]["y"].toDouble() / GameEngine.NSCALE,
          GameEngine.ENERGY_BLOCK_WIDTH, GameEngine.ENERGY_BLOCK_HEIGHT);
      this.from.userData = Sprite.from(e.world);
    }

    e.camera.reset();
    e.camera.setBounds(x, y, x + w, y + h);

    this.to = e.createPolygonShape(l["to"]["x"].toDouble() / GameEngine.NSCALE,
        l["to"]["y"].toDouble() / GameEngine.NSCALE, GameEngine.ENERGY_BLOCK_WIDTH,
        GameEngine.ENERGY_BLOCK_HEIGHT);
    this.to.userData = Sprite.to(e.world);

    for (var obstacle in l["obstacles"]) {
      Body o = e.createPolygonShape(obstacle["x"].toDouble() /
          GameEngine.NSCALE, obstacle["y"].toDouble() / GameEngine.NSCALE,
          obstacle["width"].toDouble() / GameEngine.NSCALE, obstacle["height"].toDouble()
          / GameEngine.NSCALE);
      o.userData = Sprite.byType(obstacle["type"]);
      obstacles.add(o);
    }

    e.from = this.from;
    e.to = this.to;
  }


  int getRating() {
    if (stars[0] >= e.cards.length) rating = 3; else if (stars[1] >=
        e.cards.length) rating = 2; else rating = 1;

    return rating;
  }

  void loadRating() {
    if (stars[0] >= cards.length) rating = 3; else if (stars[1] >= cards.length)
        rating = 2; else rating = 1;
  }


  void finish() {
    saveState();
    for (Body b in e.cards) {
      b.type = BodyType.STATIC;
    }


    e.physicsEnabled = false;
    e.bobbin.erase();
    e.cards.clear();

    applyPhysicsLabelToButton();
  }

  void saveState() {
    cards = new List();
    cards.addAll(e.cards);
    frames = new List();
    frames.addAll(e.bobbin.list);


    from = e.from;
    to = e.to;
    fSprite = e.from.userData;
    tSprite = e.to.userData;
  }

  void fromData(GameEngine e) {
    e.bobbin.list = frames;
  }

  void enable(bool v) {
    for (Body b in cards) {
      b.userData.enabled = v;
    }

    e.from.userData.enabled = v;
    e.to.userData.enabled = v;
  }

  void apply() {
    Function f = () {
      e.camera.setBounds(x, y, x + w, y + h);
      e.camera.mTargetX = x;
      e.camera.mTargetY = y;
      e.bobbin.list = this.frames;
      e.cards = this.cards;

      e.from = from;
      e.from.userData = Sprite.from(e.world);

      e.to = to;

      if (tSprite != null) e.to.userData = tSprite; else tSprite =
          e.to.userData;

      e.rewind();
      e.bobbin.rewindComplete = () {
        e.bobbin.rewindComplete = null;
        this.frames.clear();
        if (levelApplied != null) levelApplied();
        levelApplied = null;
      };
    };

    if (e.physicsEnabled) {
      e.bobbin.rewindComplete = f;
      e.rewind();
    } else f();
  }

  void complete() {
    for (Body b in cards) {
      (b.userData as EnergySprite).alwaysAnimate = true;
      (b.userData as EnergySprite).activate();
      (b.userData as EnergySprite).connectedToEnergy = true;
    }
  }
}
