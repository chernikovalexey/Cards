import 'dart:html';
import 'dart:math' as Math;
import 'package:box2d/box2d_browser.dart';
import 'Input.dart';
import 'GameEngine.dart';
import "Sprite.dart";
import "Color4.dart";
import 'GameWizard.dart';
import 'Tooltip.dart';

class BoundedCard {
    Body b;
    GameEngine e;

    Vector2 pos = new Vector2(0.0, 0.0);

    BoundedCard(GameEngine e) {
        this.e = e;

        BodyDef bd = new BodyDef();
        bd.type = BodyType.DYNAMIC;
        bd.position = pos;
        bd.bullet = true;

        FixtureDef fd = new FixtureDef();

        PolygonShape sd = new PolygonShape();
        sd.setAsBox(GameEngine.CARD_WIDTH / 2, GameEngine.CARD_HEIGHT / 2);
        fd.shape = sd;
        fd.isSensor = true;

        b = e.world.createBody(bd);
        b.createFixture(fd);
        b.userData = Sprite.card(e.world);
    }

    void update() {
        double angle = b.angle;
        double delta = Math.PI / 24;
        double prev_angle = angle;

        if (Input.keys['q'].down) {
            angle += delta / 2;
        } else if (Input.keys['e'].down) {
            angle -= delta / 2;
        } else {
            angle -= Input.wheelDirection * delta;
        }

        if (angle != prev_angle) {
            GameWizard.onBlockRotate();
        }

        double speed = 1.0 / GameEngine.scale;

        if (Input.mouseDeltaX != 0.0 || Input.mouseDeltaY != 0.0) {
            pos = new Vector2(Input.mouseX, Input.mouseY);
        } else {
            if (Input.keys['w'].down) {
                pos.y += speed;
            }

            if (Input.keys['a'].down) {
                pos.x -= speed;
            }

            if (Input.keys['s'].down) {
                pos.y -= speed;
            }

            if (Input.keys['d'].down) {
                pos.x += speed;
            }
        }

        b.setTransform(pos, angle);

        if (e.level.current != null) {
            Color4 col;
            if (e.staticBlocksSelected) {
                col = new Color4.fromRGB(217, 214, 179);
                if (e.physicsEnabled || e.level.current.staticBlocksRemaining == 0) col = new Color4.fromRGB(134, 133, 119);
            } else {
                col = new Color4.fromRGB(234, 140, 64);
                if (e.physicsEnabled || e.level.current.dynamicBlocksRemaining == 0) col = new Color4.fromRGB(113, 86, 64);
            }

            if (e.physicsEnabled) {
                col = new Color4.fromRGBA(0, 0, 0, 0.0);
                e.setCanvasCursor('default');
            }

            (b.userData as Sprite).color = col;
        }
    }
}
