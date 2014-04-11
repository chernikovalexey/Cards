import 'dart:html';
import 'dart:math' as Math;
import 'package:box2d/box2d_browser.dart';
import "Input.dart";
import "GameEngine.dart";
import "CardContactListener.dart";

class BoundedCard {
  Body b;
  Body boundedBox;
  bool canPut = true;

  GameEngine e;

  BoundedCard(GameEngine e) {
    this.e = e;

    BodyDef bd = new BodyDef();
    bd.type = BodyType.DYNAMIC;
    bd.position = new Vector2(0.0, 0.0);

    FixtureDef fd = new FixtureDef();

    PolygonShape sd = new PolygonShape();
    sd.setAsBox(GameEngine.CARD_WIDTH / 2, GameEngine.CARD_HEIGHT / 2);
    fd.shape = sd;
    fd.isSensor = true;

    b = e.world.createBody(bd);
    b.createFixture(fd);
    b.userData = Colors.white;
    e.world.contactListener = new CardContactListener(e);
  }

  void update() {
    double angle = b.angle;
    angle += Input.wheelDirection * Math.PI / 12;
    b.setTransform(new Vector2(Input.mouseX, Input.mouseY), angle);
    //e.addCard(this.b.position.x, this.b.position.y, angle);
  }
}
