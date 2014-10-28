import "dart:html";
import 'package:box2d/box2d_browser.dart';
import 'EnergySprite.dart';
import 'cards.dart';
import 'dart:math' as Math;

class Bobbin {
    List list = new List();

    int nFrame = 0;
    double rewindSpeed = 1.0;
    bool callbackFired = false;
    Function allAsleep;
    Function rewindComplete;

    Bobbin(Function allAsleep) {
        this.allAsleep = allAsleep;
    }

    void enterFrame(List<Body> cards) {
        nFrame++;

        List<BTransform> frame = new List();
        int numAsleep = 0;
        for (Body b in cards) {
            if (!b.awake || (b.userData as EnergySprite).isStatic) ++numAsleep;
            frame.add(new BTransform(b.position.clone(), b.angle));
        }

        if (numAsleep < cards.length) {
            list.add(frame);
        }

        if (numAsleep == cards.length && !callbackFired) {
            //analytics.applyPhysics(engine.level.chapter, engine.level.currentSubLevel);
            allAsleep();
            callbackFired = true;
        }
    }

    bool previousFrame(List<Body> cards) {
        if (list.length == 0) {
            return false;
        }
        this.rewindSpeed += .05;
        int rewindSpeed = this.rewindSpeed.round();
        List<BTransform> frame;
        if (list.length < rewindSpeed) {
            this.rewindSpeed = 1.0;
            frame = list.last;
            list.clear();
        } else {
            frame = list[list.length - rewindSpeed];
            list.removeRange(list.length - rewindSpeed, list.length);
        }

        for (int i = 0, len = frame.length; i < len; i++) {
            Body b = cards[i];
            if (!(b.userData as EnergySprite).isStatic) {
                b.setTransform(frame[i].pos, frame[i].angle);
            }
        }

        return true;
    }

    void erase() {
        nFrame = 0;
        rewindSpeed = 1.0;
        callbackFired = false;
        list.clear();
    }
}

class BTransform {
    Vector2 pos;

    double angle;

    BTransform(Vector2 pos, double angle) {
        this.pos = pos;
        this.angle = angle;
    }
}
