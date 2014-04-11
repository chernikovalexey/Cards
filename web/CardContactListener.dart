import 'dart:html';
import 'package:box2d/box2d_browser.dart';
import 'Input.dart';
import 'GameEngine.dart';

class CardContactListener extends ContactListener {
  GameEngine e;
  List<Body> contactingBodies = new List<Body>();

  bool canPut = true;

  @override
  void endContact(Contact contact) {
    if (!e.physicsEnabled) {
      canPut = true;
      contactingBodies.remove(contact.fixtureB.body);
    }
  }

  @override
  void preSolve(Contact contact, Manifold oldManifold) {
  }

  @override
  void postSolve(Contact contact, ContactImpulse impulse) {
  }

  CardContactListener(GameEngine e) {
    this.e = e;
  }

  @override
  void beginContact(Contact contact) {
    if (!e.physicsEnabled) {
      canPut = false;
      contactingBodies.add(contact.fixtureB.body);
    }
  }
}
