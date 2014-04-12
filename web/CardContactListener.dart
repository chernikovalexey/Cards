import 'dart:html';
import 'package:box2d/box2d_browser.dart';
import 'Input.dart';
import 'GameEngine.dart';

class CardContactListener extends ContactListener {
  GameEngine e;
  List<Body> contactingBodies = new List<Body>();

  @override
  void endContact(Contact contact) {
    if (!e.physicsEnabled) {
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
    if (!e.physicsEnabled && contact.fixtureB.body.userData != null &&
        !contact.fixtureB.body.userData.isInner) {
      contactingBodies.add(contact.fixtureB.body);
    }
  }
}
