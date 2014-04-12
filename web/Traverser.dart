import 'package:box2d/box2d_browser.dart';
import 'GameEngine.dart';

class Traverser {
  List<Body> traversed = new List<Body>();
  GameEngine e;

  bool hasPath = false;

  Traverser(this.e);

  void traverseEdges(ContactEdge edge) {
    //Color3 col1 = (edge.contact.fixtureA.body.userData as Sprite).color;
    //Color3 col2 = (edge.contact.fixtureB.body.userData as Sprite).color;

    if (edge.contact.fixtureA.body == e.to || edge.contact.fixtureB.body == e.to) {
      hasPath = true;
    }

    if (!traversed.contains(edge.contact.fixtureA.body) &&
        !e.obstacles.contains(edge.contact.fixtureA.body)) {
      //col1.setFromRGB(202, 201, 201);

      traversed.add(edge.contact.fixtureA.body);
      traverseEdges(edge.contact.fixtureA.body.contactList);
    }

    if (!traversed.contains(edge.contact.fixtureB.body) &&
        !e.obstacles.contains(edge.contact.fixtureB.body)) {
      //col2.setFromRGB(202, 201, 201);

      traversed.add(edge.contact.fixtureB.body);
      traverseEdges(edge.contact.fixtureB.body.contactList);
    }

    if (edge.next != null) {
      traverseEdges(edge.next);
    }
  }

  void reset() {
    traversed.clear();
    hasPath = false;
  }
}
