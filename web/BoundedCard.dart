import 'dart:html';
import 'dart:math' as Math;
import 'package:box2d/box2d_browser.dart';
import 'Input.dart';
import 'GameEngine.dart';
import "Sprite.dart";

class BoundedCard {
  Body b;

  GameEngine e;

  BoundedCard(GameEngine e) {
    this.e = e;

    BodyDef bd = new BodyDef();
    bd.type = BodyType.DYNAMIC;
    bd.position = new Vector2(0.0, 0.0);
    bd.bullet = true;

    FixtureDef fd = new FixtureDef();

    PolygonShape sd = new PolygonShape();
    sd.setAsBox(GameEngine.CARD_WIDTH / 2, GameEngine.CARD_HEIGHT / 2);
    fd.shape = sd;
    fd.isSensor = true;

    b = e.world.createBody(bd);
    b.createFixture(fd);
    b.userData = Sprite.card(e.world);
  }

  void update() {
    double angle = b.angle;
    angle += Input.wheelDirection * Math.PI / 24;
    b.setTransform(new Vector2(Input.mouseX, Input.mouseY), angle);

    Color3 col;
    if (e.staticBlocksSelected) {
      col = new Color3.fromRGB(217, 214, 179);
      if (e.physicsEnabled) col = new Color3.fromRGB(134, 133, 119);
    } else {
      col = new Color3.fromRGB(234, 140, 64);
      if (e.physicsEnabled) col = new Color3.fromRGB(113, 86, 64);
    }

    (b.userData as Sprite).color = col;
  }
}
