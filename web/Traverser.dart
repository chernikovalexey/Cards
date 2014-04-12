import 'package:box2d/box2d_browser.dart';

class Traverser {
  List<Body> traversed = new List<Body>();
  Body avoid, from, to;

  bool hasPath = false;

  Traverser(this.avoid, this.from, this.to);

  void traverseEdges(ContactEdge edge) {
    //Color3 col1 = (edge.contact.fixtureA.body.userData as Sprite).color;
    //Color3 col2 = (edge.contact.fixtureB.body.userData as Sprite).color;

    if (edge.contact.fixtureA.body == to || edge.contact.fixtureB.body == to) {
      hasPath = true;
    }

    if (!traversed.contains(edge.contact.fixtureA.body) &&
        edge.contact.fixtureA.body != avoid) {
      //col1.setFromRGB(202, 201, 201);

      traversed.add(edge.contact.fixtureA.body);
      traverseEdges(edge.contact.fixtureA.body.contactList);
    }

    if (!traversed.contains(edge.contact.fixtureB.body) &&
        edge.contact.fixtureB.body != avoid) {
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
