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

    int frame = 0;

    bool active = false;

    Body from;

    EnergySprite(World w) {
        if (GLOW_COLORS.length == 0) {
            GLOW_COLORS.add(new Color3.fromRGB(255, 255, 0));
            GLOW_COLORS.add(new Color3.fromRGB(255, 220, 0));
            GLOW_COLORS.add(new Color3.fromRGB(255, 200, 0));
        }

        this.color = new Color3.fromRGB(255, 250, 200);
    }

    void glow(CanvasDraw g, Body b, double w, double h, int state) {
        if (from == null) return;


        PolygonShape shape = (b.fixtureList.shape as PolygonShape);

        PolygonShape shape1 = shape.clone();

        //todo: test!
        if (from.position.distanceTo(shape1.vertices[1]) < from.position.distanceTo(shape1.vertices[1])) {
            shape1.vertices[1].x -= GameEngine.CARD_WIDTH * (1 - energy);
            shape1.vertices[2].x -= GameEngine.CARD_WIDTH * (1 - energy);
        } else {
            shape1.vertices[0].x += GameEngine.CARD_WIDTH * (1 - energy);
            shape1.vertices[3].x += GameEngine.CARD_WIDTH * (1 - energy);
        }

        for (Vector2 v in shape1.vertices) {
            v.x += v.x * (0.1 * state / 3);
            v.y += v.y * (0.4 * state / 3);
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

    void activate(Body from) {
        this.from = from;
        active = true;
    }

    void deactivate(Body from) {
        this.from = from;
        active = false;
    }

    @override

    void render(CanvasDraw g, Body b) {
        if(isHidden) return;
        super.render(g, b);

        frame++;

        if (!active && energy <= 0) return;

        if (active && energy < .9) {
            energy += 0.1;
        } else if (!active && energy >= .1) {
            energy -= 0.1;
        }

        if (frame % 12 == 0) {
            if (glowBorders == 2 || glowBorders == 0)
                glowAdd *= -1;
            glowBorders += glowAdd;

        }
        glowEffect(g, b, glowBorders);

    }


}
