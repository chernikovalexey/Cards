import 'package:box2d/box2d_browser.dart';
import 'GameEngine.dart';

class Traverser {
    List<Body> traversed = new List<Body>();

    GameEngine e;

    bool hasPath = false;

    Traverser(this.e);


    void traverseEdges(ContactEdge edge) {
        if (edge == null) return;

        if (edge.contact.fixtureA.body == e.to || edge.contact.fixtureB.body == e.to) {
            hasPath = true;
        }


        if (edge.contact.touching) {
            if (edge.contact.fixtureA.body.userData.energySupport) {
                edge.contact.fixtureA.body.userData.connectedToEnergy = true;
                edge.contact.fixtureA.body.userData.bFrom = edge.contact.fixtureB.body;
            }

            if (edge.contact.fixtureB.body.userData.energySupport) {
                edge.contact.fixtureB.body.userData.connectedToEnergy = true;
                edge.contact.fixtureB.body.userData.bFrom = edge.contact.fixtureA.body;
            }
        }

        if (edge.next != null) {
            traverseEdges(edge.next);
        }

        if (edge.contact.touching) {
            if (!traversed.contains(edge.contact.fixtureA.body) &&
            !e.level.current.obstacles.contains(edge.contact.fixtureA.body)) {
//col1.setFromRGB(202, 201, 201);

                traversed.add(edge.contact.fixtureA.body);
                traverseEdges(edge.contact.fixtureA.body.contactList);
            }

            if (!traversed.contains(edge.contact.fixtureB.body) &&
            !e.level.current.obstacles.contains(edge.contact.fixtureB.body)) {
//col2.setFromRGB(202, 201, 201);

                traversed.add(edge.contact.fixtureB.body);
                traverseEdges(edge.contact.fixtureB.body.contactList);
            }
        }

    }

    void reset() {
        traversed.clear();
        hasPath = false;
    }
}
