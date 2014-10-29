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
        //if (!e.physicsEnabled) {
            contact.fixtureA.body.userData.contactOverlay = false;
            contact.fixtureB.body.userData.contactOverlay = false;
            contactingBodies.remove(contact.fixtureB.body);
        //}
    }

    @override
    void preSolve(Contact contact, Manifold oldManifold) {
    }

    @override
    void postSolve(Contact contact, ContactImpulse impulse) {
    }

    void beginContact(Contact contact) {
        if (!contact.touching) return;

        if (!e.physicsEnabled && !contact.fixtureB.isSensor && contact.fixtureB.body.userData != null && !contact.fixtureB.body.userData.isHint && !contact.fixtureB.body.userData.isInner) {
            contact.fixtureA.body.userData.contactOverlay = true;
            contact.fixtureB.body.userData.contactOverlay = true;
            contactingBodies.add(contact.fixtureB.body);
        }
    }
}
