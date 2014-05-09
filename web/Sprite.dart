import "dart:html";
import 'package:box2d/box2d_browser.dart';
import "EnergySprite.dart";

class Sprite {
    double energy = 0.0;
    bool isInner = false;
    bool isHidden = false;
    bool active = false;
    bool connectedToEnergy = false;
    bool energySupport = false;
    bool isStatic = false;
    bool enabled = true;

    Body bFrom;


    Color3 color;

    CanvasDraw canvasDraw;

    Vector2 center;
    Vector2 axis;

    Sprite() {
        center = new Vector2.zero();
        axis = new Vector2.zero();
    }

    void render(CanvasDraw g, Body b) {
        if(isHidden) return;

        canvasDraw = g;
        Transform tf = new Transform();
        tf.setFrom(b.originTransform);
        drawShape(b.fixtureList, tf, color);

    }

    void drawShape(Fixture fixture, Transform xf, Color3 color) {
        if(fixture.userData==false) {
            if(fixture.next!=null) fixture = fixture.next;
            else return;
        }
        switch (fixture.type) {
            case ShapeType
        .
        CIRCLE:
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

            case ShapeType
        .
        POLYGON:
                final PolygonShape poly = fixture.shape;
                int vertexCount = poly.vertexCount;
                assert (vertexCount <= Settings.MAX_POLYGON_VERTICES);
                List<Vector2> vertices = new List<Vector2>.generate(
                    vertexCount, (i) => new Vector2.zero());

                for (int i = 0; i < vertexCount; ++i) {
                    assert(poly.vertices[i] != null);
                    assert(vertices[i] != null);
                    Transform.mulToOut(xf, poly.vertices[i], vertices[i]);
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

    void activate() {}
    void deactivate() {}

    static Sprite card(World w) {
        return new EnergySprite(w);
    }

    static Sprite innerEnergy() {
        Sprite s = new Sprite();
        s.color = new Color3.fromRGB(255,242,0);
        s.isInner = true;
        return s;
    }

    static Sprite from(World w) {
        EnergySprite s = new EnergySprite(w);
        s.energy = 1.0;
        s.alwaysAnimate = true;
        s.connectedToEnergy = true;
        s.activate();
        return s;
    }

    static Sprite to(World w) {
        EnergySprite s = new EnergySprite(w);;
        //s.alwaysAnimate = true;
        s.energy = 0.0;
        s.active = true;
        s.energyStep = .01;
        return s;
    }

    static Sprite ground() {
        Sprite s = new Sprite();
        s.color = new Color3.fromRGB(128, 128, 0);
        return s;
    }
    
    static Sprite byType(int type) {
      switch(type) {
        case 1:
          return ground();
        case 2:
          return from();
        case 3:
          return to();
      }
      return null;
    }
}
