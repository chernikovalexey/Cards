import 'dart:html';
import 'package:box2d/box2d_browser.dart';
import 'Input.dart';
import 'GameEngine.dart';
import 'Sprite.dart';
import 'EnergySprite.dart';

class CardContactListener extends ContactListener {
  GameEngine e;
  List<Body> contactingBodies = new List<Body>();

  CardContactListener(this.e);

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

  void beginContact(Contact contact) {
    if (e.physicsEnabled) {
      Body b = e.world.bodyList;
      while (b != null) {
        b.userData.connectedToEnergy = false;
        b = b.next;
      }

      e.traverser.reset();
      e.traverser.traverseEdges(e.from.contactList);

    }

    if (!e.physicsEnabled && contact.fixtureB.body.userData != null &&
        !contact.fixtureB.body.userData.isInner) {
      contactingBodies.add(contact.fixtureB.body);
    }
  }
}
