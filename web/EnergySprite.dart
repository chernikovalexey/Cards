import "Sprite.dart";
import "dart:html";
import "GameEngine.dart";
import 'package:box2d/box2d_browser.dart';


class EnergySprite extends Sprite {
    Body inner;

    static List<Color3> GLOW_COLORS = new List();

    int glowBorders = 1;

    int glowAdd = 1;

    int frame = 0;

    bool active = false;

    Body from;

    EnergySprite(World w) {
        activate(null);
        if (GLOW_COLORS.length == 0) {
            GLOW_COLORS.add(new Color3.fromRGB(255, 255, 0));
            GLOW_COLORS.add(new Color3.fromRGB(255, 220, 0));
            GLOW_COLORS.add(new Color3.fromRGB(255, 200, 0));
        }

        this.color = new Color3.fromRGB(255, 250, 200);
    }

    void glow(CanvasDraw g, Body b, double w, double h, int color) {
        double x = (b.fixtureList.shape as PolygonShape).getVertex(0).x;
        double y = (b.fixtureList.shape as PolygonShape).getVertex(0).y;

        double cx = x + w / 2;
        double cy = y + h / 2;

        print(cx.toString()+" " + cy.toString());



        FixtureDef fd = new FixtureDef();
        PolygonShape ps = new PolygonShape();

        ps.setAsBox(w, h);
        fd.shape = ps;
        Fixture f = new Fixture();
        f.create(null, fd);

        Transform tf = new Transform();
        tf.setFrom(b.originTransform);
        tf.position.x = cx;
        tf.position.y = cy;


        drawShape(f, tf, GLOW_COLORS[color]);
    }

    void glowEffect(CanvasDraw g, Body b, int n) {
        if (n >= 2)
            glow(g, b, (GameEngine.CARD_WIDTH /2 + 0.004) * energy, GameEngine.CARD_HEIGHT / 2 + .004, 2);

        if (n >= 1)
            glow(g, b, GameEngine.CARD_WIDTH / 2 + 0.002, GameEngine.CARD_HEIGHT / 2 + .002, 1);

        glow(g, b, GameEngine.CARD_WIDTH / 2 * energy , GameEngine.CARD_HEIGHT / 2 , 0);
    }

    void activate(Body from) {
        active = true;
        energy = 0.5;
    }

    @override
    void render(CanvasDraw g, Body b) {
        super.render(g, b);

        frame++;

        if(!active) return;

        if (frame % 10 == 0) {
            if (glowBorders == 2 || glowBorders == 0)
                glowAdd *= -1;
            glowBorders += glowAdd;

        }
        glowEffect(g, b, glowBorders);

    }


}
