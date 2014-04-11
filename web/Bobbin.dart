import "dart:html";
import 'package:box2d/box2d_browser.dart';

class Bobbin {
  List list = new List();

  int nFrame = 1;

  Bobbin() {
  }

  void enterFrame(List<Body> cards) {
    nFrame++;
    if (nFrame % 2 == 0) return;

    List<Body> frame = new List();
    int numAsleep = 0;
    for (Body b in cards) {
      if (!b.awake) numAsleep++;
      frame.add(new Transform(b.position.clone(), b.angle));
    }

    if (numAsleep < cards.length) list.add(frame);
    print(list.length);
  }

  bool previousFrame(List<Body> cards) {
    if (list.length == 0) return false;
    List<Transform> frame = list.last;
    list.remove(frame);
    for (int i = 0; i < frame.length; i++) {
      Body b = cards[i];
      b.setTransform(frame[i].pos, frame[i].angle);
    }

    return true;
  }
}

class Transform {
  Vector2 pos;

  double angle;

  Transform(Vector2 pos, double angle) {
    this.pos = pos;
    this.angle = angle;
  }
}
