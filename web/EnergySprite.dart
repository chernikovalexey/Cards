import "Sprite.dart";
import "dart:html";
import "GameEngine.dart";
import 'package:box2d/box2d_browser.dart';
import "dart:math" as Math;


class EnergySprite extends Sprite {
    Body inner;

    static List<Color3> GLOW_COLORS = new List();

    int glowBorders = 1;

    int glowAdd = 1;

    double energyStep = .1;

    int frame = 0;

    bool alwaysAnimate = false;

    Body current;

    EnergySprite(World w) {
        energySupport = true;
        if (GLOW_COLORS.length == 0) {
            GLOW_COLORS.add(new Color3.fromRGB(29, 78, 187));
            GLOW_COLORS.add(new Color3.fromRGB(255, 220, 0));
            GLOW_COLORS.add(new Color3.fromRGB(255, 200, 0));
        }

        this.color = new Color3.fromRGB(234, 140, 64);
    }

    int sign(double x) {
        return x>0?1:-1;
    }

    void glow(CanvasDraw g, Body b, double w, double h, int state) {

        if (bFrom == null && !alwaysAnimate) return;
        if(!active) return;
        if(alwaysAnimate && bFrom==null) bFrom = b;

        Fixture fixture = b.fixtureList;
        if(fixture.userData==false) {
            if(fixture.next!=null) fixture = fixture.next;
            else return;
        }


        PolygonShape shape = (fixture.shape as PolygonShape);

        PolygonShape shape1 = shape.clone();

        if (bFrom.position.distanceTo(shape1.vertices[2]) > bFrom.position.distanceTo(shape1.vertices[3])) {
            shape1.vertices[1].x -= GameEngine.CARD_WIDTH * (1 - energy);
            shape1.vertices[2].x -= GameEngine.CARD_WIDTH * (1 - energy);
        } else {
            shape1.vertices[0].x += GameEngine.CARD_WIDTH * (1 - energy);
            shape1.vertices[3].x += GameEngine.CARD_WIDTH * (1 - energy);
        }

        for (Vector2 v in shape1.vertices) {
            v.x += sign(v.x) * .005 * state;
            v.y += sign(v.y) * .005 * state;
        }

        FixtureDef fd = new FixtureDef();
        fd.shape = shape1;


        Fixture f = new Fixture();
        f.create(null, fd);


        drawShape(f, b.originTransform, GLOW_COLORS[0]);
    }

    void glowEffect(CanvasDraw g, Body b, int n) {
        glow(g, b, GameEngine.CARD_WIDTH / 2 * energy, GameEngine.CARD_HEIGHT / 2, n);
    }

    void activate() {
        active = true;
    }

    void deactivate() {
        active = false;
        connectedToEnergy = false;
    }

    @override

    void render(CanvasDraw g, Body b) {
        if(energy<0) energy = 0.0;
        else if(energy>1) energy = 1.0;
        current = b;

        if (isHidden) return;

        super.render(g, b);

        frame++;

        if (!active && energy <= 0) return;

        if (active && energy <= 1 - energyStep) {
            energy += energyStep;
        } else if (!active && energy >= energyStep) {
            energy -= energyStep;
        }

        if (frame % 10 == 0) {
            if (glowBorders == 2 || glowBorders == 0)
                glowAdd *= -1;
            glowBorders += glowAdd;

        }
        glowEffect(g, b, glowBorders);

    }

    void update(GameEngine e) {
        if(!e.physicsEnabled) return;
        if(active && !connectedToEnergy)
            deactivate();
        else if(!active && connectedToEnergy)
            activate();
    }

    bool isFull() {
        return energy >= 1 - energyStep;
    }
}
