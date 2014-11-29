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
        Fixture fx = contact.fixtureA.isSensor ? contact.fixtureB : contact.fixtureA;
        contact.fixtureA.body.userData.contactOverlay = false;
        contact.fixtureB.body.userData.contactOverlay = false;
        contactingBodies.remove(fx.body);
    }

    @override
    void preSolve(Contact contact, Manifold oldManifold) {
    }

    @override
    void postSolve(Contact contact, ContactImpulse impulse) {
    }

    void beginContact(Contact contact) {
        if (!contact.touching) return;

        Fixture fx = contact.fixtureA.isSensor ? contact.fixtureB : contact.fixtureA;

        if (!e.physicsEnabled && !fx.isSensor && fx.body.userData != null && !fx.body.userData.isHint && !fx.body.userData.isInner) {
            contact.fixtureA.body.userData.contactOverlay = true;
            contact.fixtureB.body.userData.contactOverlay = true;
            contactingBodies.add(fx.body);
        }
    }
}
