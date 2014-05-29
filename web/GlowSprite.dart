import "Sprite.dart";
import "dart:html";
import "GameEngine.dart";
import 'package:box2d/box2d_browser.dart';
import "dart:math" as Math;
import "Color4.dart";
import "SuperCanvasDraw.dart";
import "EnergySprite.dart";
import "DoubleAnimation.dart";


class GlowSprite extends Sprite {
    static const int FRAME_COUNT = 20;

    DoubleAnimation animation;

    double additionalOffset;

    double dFrom, dTo;

    GlowSprite(this.dFrom, this.dTo, this.additionalOffset) {
        animation = new DoubleAnimation(dFrom, dTo, FRAME_COUNT);
        color = new Color4.fromRGBA(29, 78, 187, dFrom);
    }

    int getNearestPoints(Body from, Body to) {
        if(from==to) {
            return 0;
        }

        PolygonShape ps = to.fixtureList.shape.clone();
        PolygonShape s1 = from.fixtureList.shape;

/*for(Vector2 v in ps.vertices) {
            v.x += (v.x > 0 ? 1 : -1) * .05;
            v.y += (v.y > 0 ? 1 : -1) * .05;
        }*/

        for (int i = 0;i < ps.vertices.length;i++) {
            if(s1.testPoint(from.originTransform, to.getWorldPoint(ps.vertices[i])))
                return i;
        }

        return -1;
    }

    void render(SuperCanvasDraw g, Body b) {

        EnergySprite parent = (b.userData as EnergySprite);
        if (!parent.active && !parent.alwaysAnimate) return;
        Body bFrom = parent.bFrom;
        if (parent.alwaysAnimate)  {
            bFrom = b;
        }
        if (bFrom == null) return;

        PolygonShape shape = b.fixtureList.next.shape.clone() as PolygonShape;
        this.energy = (b.userData as Sprite).energy;

        shape.vertices[0].x += GameEngine.CARD_WIDTH * (1 - energy) / 2;
        shape.vertices[3].x += GameEngine.CARD_WIDTH * (1 - energy) / 2;

        shape.vertices[1].x -= GameEngine.CARD_WIDTH * (1 - energy) / 2;
        shape.vertices[2].x -= GameEngine.CARD_WIDTH * (1 - energy) / 2;


        for (Vector2 v in shape.vertices) {
            v.x += (v.x > 0 ? 1 : -1) * additionalOffset;
            v.y += (v.y > 0 ? 1 : -1) * additionalOffset;
        }

        color.a = animation.next();
        if (animation.isFinished) {
            animation = new DoubleAnimation(dTo, dFrom, FRAME_COUNT);
            dFrom = animation.start;
            dTo = animation.end;
        }

        FixtureDef fd = new FixtureDef();
        fd.shape = shape;


        Fixture f = new Fixture();
        f.create(null, fd);

        canvasDraw = g;
        drawShape(f, b.originTransform, color);
    }
}