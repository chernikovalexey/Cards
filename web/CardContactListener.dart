import 'dart:html';
import 'dart:math' as Math;
import 'package:box2d/box2d_browser.dart';
import "Input.dart";
import "GameEngine.dart";
import "CardContactListener.dart";

class CardContactListener extends ContactListener {
  GameEngine e;

  @override
  void endContact(Contact contact) {
    if (!e.physicsEnabled) {
      e.bcard.canPut = true;
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
      e.bcard.canPut = false;
    }
  }
}
