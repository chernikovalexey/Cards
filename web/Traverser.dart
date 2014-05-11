import 'package:box2d/box2d_browser.dart';
import 'GameEngine.dart';
import 'Sprite.dart';

class Traverser {
    List<Body> traversed = new List<Body>();

    GameEngine e;
    Body to;

    bool hasPath = false;

    Traverser(this.e);

    Traverser.subLevel(this.to);


    void traverseEdges(ContactEdge edge, [bool makeFull=false]) {
        if (edge == null) return;

        Body to = null;
        if(this.to!=null) to = this.to;
        else to = e.to;

        if (edge.contact.fixtureA.body == to || edge.contact.fixtureB.body == to) {
            hasPath = true;
        }


        if (edge.contact.touching) {
            if (edge.contact.fixtureA.body.userData.energySupport) {
                edge.contact.fixtureA.body.userData.connectedToEnergy = true;
                edge.contact.fixtureA.body.userData.bFrom = edge.contact.fixtureB.body;
                if(makeFull) {
                    print("Make full");
                    edge.contact.fixtureA.body.userData.enable(true);
                    edge.contact.fixtureA.body.userData.energy = 1.0;
                }
// edge.contact.fixtureA.body.userData.color = new Color3.fromRGB(255, 0, 0);
            }

            if (edge.contact.fixtureB.body.userData.energySupport) {
                edge.contact.fixtureB.body.userData.connectedToEnergy = true;
                edge.contact.fixtureB.body.userData.bFrom = edge.contact.fixtureA.body;
                if(makeFull) {
                    print("Make full");
                    edge.contact.fixtureB.body.userData.enable(true);
                    edge.contact.fixtureB.body.userData.energy = 1.0;
                }
//  edge.contact.fixtureB.body.userData.color = new Color3.fromRGB(255, 0, 0);
            }
        }

        if (edge.next != null) {
            traverseEdges(edge.next);
        }

        if (edge.contact.touching) {
            if (edge.contact.fixtureA.body.userData.energySupport) {
                if (!traversed.contains(edge.contact.fixtureA.body)) {
//col1.setFromRGB(202, 201, 201);

                    traversed.add(edge.contact.fixtureA.body);
                    traverseEdges(edge.contact.fixtureA.body.contactList, makeFull);
                }
            }

            if (edge.contact.fixtureB.body.userData.energySupport) {

                if (!traversed.contains(edge.contact.fixtureB.body)) {
//col2.setFromRGB(202, 201, 201);

                    traversed.add(edge.contact.fixtureB.body);
                    traverseEdges(edge.contact.fixtureB.body.contactList, makeFull);
                }
            }
        }

    }

    bool checkEnergyConnection(Body b) {
        for(ContactEdge item = b.contactList; item!=null; item = item.next) {
            if(item.contact.touching) {
                Sprite a = item.contact.fixtureA.body.userData as Sprite;
                Sprite b = item.contact.fixtureB.body.userData as Sprite;
                if(a.energy>0 || b.energy>0) {
                    return true;
                }
            }
        }

        return false;
    }

    void reset() {
        traversed.clear();
        hasPath = false;
    }
}
