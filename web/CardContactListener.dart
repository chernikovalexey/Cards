import 'dart:html';
import 'dart:math' as Math;
import 'package:box2d/box2d_browser.dart';
import "Input.dart";
import "GameEngine.dart";
import "CardContactListener.dart";

class CardContactListener extends ContactListener {
  GameEngine e;

  void endContact(Contact contact) {
  }

  void preSolve(Contact contact, Manifold oldManifold) {
  }

  void postSolve(Contact contact, ContactImpulse impulse) {
  }

  CardContactListener(GameEngine e) {
    this.e = e;
    print("card listener");
  }

  void beginContact(Contact contact) {
    if(e.bcard == contact.fixtureA.body) {
      e.bcard.alert();
    }
  }


}
