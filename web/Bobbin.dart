import "dart:html";
import 'package:box2d/box2d_browser.dart';
import 'EnergySprite.dart';

class Bobbin {
  List list = new List();

  int nFrame = 1;
  bool callbackFired = false;
  Function allAsleep;

  Bobbin(Function allAsleep) {
    this.allAsleep = allAsleep;
  }

  void enterFrame(List<Body> cards) {
    nFrame++;
    if (nFrame % 2 == 0) return;

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
      allAsleep();
      callbackFired = true;
    }
  }

  bool previousFrame(List<Body> cards) {
    if (list.length == 0) return false;
    List<BTransform> frame = list.last;
    list.remove(frame);
    for (int i = 0, len = frame.length; i < len; i++) {
      Body b = cards[i];
      if(!(b.userData as EnergySprite).isStatic) {
        b.setTransform(frame[i].pos, frame[i].angle);
      }
    }

    return true;
  }

  void erase() {
    nFrame = 1;
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
