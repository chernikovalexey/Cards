import "dart:html";
import 'package:box2d/box2d_browser.dart';
import "EnergySprite.dart";
import "SuperCanvasDraw.dart";
import "Color4.dart";

class Sprite {
    static int CURRENT_ID = 0;

    double energy = 0.0;

    bool isInner = false;

    bool isHidden = false;

    bool active = false;

    bool connectedToEnergy = false;

    bool energySupport = false;

    bool isStatic = false;

    bool isHint = false;

    bool contactOverlay = false;

    bool enabled = true;

    double px = 0.0;
    double py = 0.0;
    double gravity = 0.0;

    // for dynamic obstacles only
    int id;

    Body bFrom;

    Color4 color;

    SuperCanvasDraw canvasDraw;

    Vector2 center;

    Vector2 axis;

    Sprite() {
        center = new Vector2.zero();
        axis = new Vector2.zero();
    }

    void render(SuperCanvasDraw g, Body b) {
        if (isHidden) return;

        this.canvasDraw = g;
        Transform tf = new Transform();
        tf.setFrom(b.originTransform);
        drawShape(b.fixtureList, tf, color);

        if (contactOverlay) {
            drawShape(b.fixtureList, tf, new Color4.fromRGBA(220, 30, 30, 0.425));
        }
    }

    void drawShape(Fixture fixture, Transform xf, Color4

    color) {
        if (fixture.userData == false) {
            if (fixture.next != null) fixture = fixture.next; else return;
        }
        switch (fixture.type) {
            case ShapeType.CIRCLE:
                final CircleShape circle = fixture.shape;

// Vector2 center = Mul(xf, circle.p);
                Transform.mulToOut(xf, circle.position, center);
                num radius = circle.radius;
                axis.setValues(xf.rotation.entry(0, 0), xf.rotation.entry(1, 0));

                if (0 != (canvasDraw.flags & DebugDraw.e_lineDrawingBit)) {
                    canvasDraw.drawCircle(center, radius, color, axis);
                } else {
                    canvasDraw.drawSolidCircle(center, radius, color, axis);
                }
                break;

            case ShapeType.POLYGON:
                final PolygonShape poly = fixture.shape;
                int vertexCount = poly.vertexCount;
                assert (vertexCount <= Settings.MAX_POLYGON_VERTICES);
                List<Vector2> vertices = new List<Vector2>.generate(vertexCount, (i) => new Vector2.zero());

                for (int i = 0; i < vertexCount; ++i) {
                    assert(poly.vertices[i] != null);assert(vertices[i] != null);Transform.mulToOut(xf, poly.vertices[i], vertices[i]);
                }

                if (0 != (canvasDraw.flags & DebugDraw.e_lineDrawingBit)) {
                    canvasDraw.drawPolygon(vertices, vertexCount, color);
                } else if (vertexCount > 2) {
                    canvasDraw.drawSolidPolygon(vertices, vertexCount, color);
                } else {
                    canvasDraw.drawPolygon(vertices, vertexCount, color);
                }
                break;
        }
    }

    void activate() {
    }

    void deactivate() {
    }

    static Sprite card(World w) {
        return new EnergySprite(w);
    }

    static Sprite innerEnergy() {
        Sprite s = new Sprite();
        s.color = new Color4.fromRGB(255, 242, 0);
        s.isInner = true;
        return s;
    }

    static Sprite from(World w, [bool active = true]) {
        EnergySprite s = new EnergySprite(w, false);
        s.isCard = false;

        if (active) {
            s.energy = 1.0;
            s.alwaysAnimate = true;
            s.connectedToEnergy = true;
            s.active = true;
        } else {
            s.energy = 0.0;
            s.alwaysAnimate = false;
            s.connectedToEnergy = false;
            s.active = false;
        }

        return s;
    }

    static Sprite to(World w) {
        EnergySprite s = new EnergySprite(w, false);
        s.energy = 0.0;
        s.active = true;
        s.energyStep = .1;
        return s;
    }

    static Sprite ground() {
        Sprite s = new Sprite();
        s.color = new Color4.fromRGBA(42, 42, 42, 1.0);
        return s;
    }

    static Sprite byType(int type, World w) {
        switch (type) {
            case 1:
                return ground();
            case 2:
                return from(w);
            case 3:
                return to(w);
            case 4:
                Sprite obstacle = ground();
                obstacle.color = new Color4.fromRGB(96, 74, 74);
                return obstacle;
        }
        return null;
    }
}
