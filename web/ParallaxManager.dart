import 'dart:html';
import 'dart:math' as Math;
import 'dart:convert';
import 'Input.dart';
import 'StateManager.dart';
import 'GameEngine.dart';
import 'package:box2d/box2d_browser.dart';
import "ChanceEngine.dart";
import "cards.dart";

Math.Random random = new Math.Random();

Color3 YELLOW = new Color3.fromRGB(254, 251, 224);

Color3 CYAN = new Color3.fromRGB(125, 165, 253);

class Star {

    int starId = 1;

// 0-4 image id

    bool extinct = false;

    double x = 0.0, y = 0.0;

    double cx = Input.canvasWidth / 2, cy = Input.canvasHeight / 2;

    double r, startR;

    double size;

    double speed, angle = .0;

    double angularSpeed = 0.0, radiusSpeed;

    List<Vector2> previous;

    double tailSpeed = .15;

    Star(this.x, this.y, this.speed) {

        Vector2 pv = new Vector2(x, y);
        Vector2 cv = new Vector2(cx, cy);
        startR = r = pv.distanceTo(cv);
        angle = random.nextDouble() * Math.PI * 2;
        size = 16.0;

        starId = ChanceEngine.SelectFired([.5, .25, .2499, .0001]);
    }

    void update(num delta, int modifier) {

        angularSpeed = 1 / (r / 1.5);
        var curAngSpeed = angularSpeed;
        var curRSpeed = .1;
        if (engine.ready && !engine.physicsEnabled) {
            curAngSpeed /= -15;
            curRSpeed /= -15;
        }

        x = cx + r * Math.sin(angle);
        y = cy + r * Math.cos(angle);
        angle += curAngSpeed;
        r -= curRSpeed;
        double k = r / startR;
        size = 16 * (k < 1 ? k : 1);

        if (r < 15) extinct = true;
    }

    void render(CanvasRenderingContext2D g, ImageElement sprite) {

        g.globalAlpha = .30;
        g.drawImageScaledFromSource(sprite, starId * 16, 0, 16, 16, x, y, size, size);
        g.globalAlpha = 1.0;
    }
}

class ParallaxManager extends State {
    GameEngine engine;

    CanvasRenderingContext2D g;

    num lastStepTime = 0;

    int layers, amount;

    static final int DOWN = 1;

    static final int UP = -1;

    int modifier = DOWN;

    List<Star> stars = new List<Star>();

    ImageElement sprite;

    ParallaxManager(this.engine, this.g, this.layers, this.amount) {

        sprite = new ImageElement(src: "img/stars.png");
        sprite.onLoad.listen((e) {
            print("stars are loaded");
        });
        for (int i = 0; i < amount; i++)
            stars.add(new Star(random.nextDouble() * Input.canvasWidth * 2 - Input.canvasWidth / 2, random.nextDouble() * Input.canvasHeight * 2 - Input.canvasHeight / 2, 0.0));
    }

    static Star getStar() {

        double x = ChanceEngine.InvokeFired([.5], [() => -random.nextDouble() * 400, () => Input.canvasWidth + random.nextDouble() * 400]) as double;
        double y = ChanceEngine.InvokeFired([.5], [() => -random.nextDouble() * 400, () => Input.canvasHeight + random.nextDouble() * 400]) as double;
        return new Star(x, y, 0.0);
    }

    @override
    void start([Map params]) {
    }

    @override
    void update(num delta) {
        List<Star> _stars = new List<Star>();
        _stars.addAll(stars);
        for (Star star in _stars) {
            star.update(delta, modifier);

            if (star.extinct) {
                stars.remove(star);
            }
        }
// Generate lacking stars
        for (int i = 0; i < amount - stars.length; ++i) {
            int layer = random.nextInt(layers);
            stars.add(getStar());
        }
    }

    @override
    void render() {
        g.fillStyle = 'rgba(0, 0, 0, 1)';
        g.fillRect(0, 0, Input.canvasWidth, Input.canvasHeight);
        for (Star star in stars) {
            star.render(g, sprite);
        }
    }
}
