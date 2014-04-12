import "dart:html";
import 'package:box2d/box2d_browser.dart';
import "GameEngine.dart";
import "Input.dart";
import "DoubleAnimation.dart";
import "dart:math" as Math;

class Camera {
    static final int FRAME_COUNT = 20;

    double finalZoom = 1.0;

    double startZoom = 1.0;

    double currentZoom = 1.0;

    num offsetX = 0.0, offsetY = 0.0;

    DoubleAnimation zoomAnimation = new DoubleAnimation(1.0, 1.0, FRAME_COUNT);

    GameEngine e;

    Camera(GameEngine e) {
        this.e = e;
    }

    void beginZoom(double finalZoom, double currentZoom) {
        this.finalZoom = finalZoom;
        this.startZoom = currentZoom;
        zoomAnimation = new DoubleAnimation(currentZoom, finalZoom, FRAME_COUNT);
    }

    void update() {
        move();


        if (!zoomAnimation.isFinished) {
            double zoom = zoomAnimation.next();
            currentZoom = zoom;
            updateEngine(zoom);
            if (!zoomAnimation.isFinished) currentZoom = finalZoom;
        }
    }

    void updateEngine(double zoom) {
        e.viewport = new CanvasViewportTransform(new Vector2(0.0, 0.0), new Vector2(offsetX, GameEngine.HEIGHT - offsetY));
        GameEngine.scale = e.viewport.scale = GameEngine.SCALE * zoom;

        e.debugDraw = new CanvasDraw(e.viewport, e.g);
        e.world.debugDraw = e.debugDraw;
    }


    void move() {
        if(Input.leftArrowDown)
            offsetX-=10;
        else if(Input.rightArrowDown)
            offsetX+=10;
        else if(Input.upArrowDown)
            offsetY-=10;
        else if(Input.downArrowDown)
            offsetY+=10;

        if(Input.leftArrowDown || Input.rightArrowDown || Input.upArrowDown || Input.downArrowDown)
            updateEngine(currentZoom);

    }
}
