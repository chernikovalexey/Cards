import "dart:html";
import 'package:box2d/box2d_browser.dart';
import "GameEngine.dart";
import "Input.dart";
import 'Sprite.dart';
import "DoubleAnimation.dart";
import "dart:math" as Math;
import "SuperCanvasDraw.dart";

class Camera {
    static const int FRAME_COUNT = 75;

    bool hasBounds = false;

    double finalZoom = 1.0;
    double startZoom = 1.0;
    double currentZoom = 1.0;
    double targetOffsetX = 0.0, targetOffsetY = 0.0, pxOffsetX = 0.0, pxOffsetY = 0.0;

    // in pixels
    double bx1, by1, bx2, by2;

    // in box2d measurements

    double get mTargetX => targetOffsetX / GameEngine.scale;

    double get mTargetY => -targetOffsetY / GameEngine.scale;

    set mTargetX(double offset) {
        this.targetOffsetX = offset * GameEngine.scale;
    }

    set mTargetY(double offset) {
        this.targetOffsetY = -offset * GameEngine.scale;
    }

    bool ignoreXAnim = false;
    bool ignoreYAnim = false;

    bool firedMovingEnd = true;
    bool firedZoomEnd = true;

    Function movingEnd = () {
    };
    Function zoomEnd = () {
    };

    DoubleAnimation zoomAnimation = new DoubleAnimation(1.0, 1.0, FRAME_COUNT / 3);
    DoubleAnimation xAnim = new DoubleAnimation(0.0, 0.0, FRAME_COUNT);
    DoubleAnimation yAnim = new DoubleAnimation(0.0, 0.0, FRAME_COUNT);

    GameEngine e;

    Camera(GameEngine e) {
        this.e = e;
        Input.setCamera(this);
    }

    void reset() {
        pxOffsetX = 0.0;
        pxOffsetY = 0.0;
        targetOffsetX = 0.0;
        targetOffsetY = 0.0;
    }

    void beginZoom(double finalZoom, double currentZoom) {
        this.finalZoom = finalZoom;
        this.startZoom = currentZoom;
        zoomAnimation = new DoubleAnimation(currentZoom, finalZoom, FRAME_COUNT / 3);
    }

    void update(num delta) {
        double ppx = pxOffsetX;
        if (!xAnim.isFinished && !ignoreXAnim) {
            double nx = xAnim.next();
            pxOffsetX = nx;
        }

        double ppy = pxOffsetY;
        if (!yAnim.isFinished && !ignoreYAnim) {
            double ny = yAnim.next();
            pxOffsetY = ny;
        }

        if (ppx == pxOffsetX && ppy == pxOffsetY && !firedMovingEnd) {
            firedMovingEnd = true;
            movingEnd();
        } else if (ppx != pxOffsetX || ppy != pxOffsetY) {
            firedMovingEnd = false;
        }

        if (xAnim.isFinished) {
            xAnim.setStart(targetOffsetX);
            xAnim.setFrames(FRAME_COUNT);
        }
        if (yAnim.isFinished) {
            yAnim.setStart(targetOffsetY);
            yAnim.setFrames(FRAME_COUNT);
        }

        move();

        if (!zoomAnimation.isFinished) {
            currentZoom = zoomAnimation.next();
            updateZoom();

            if (zoomAnimation.isFinished && !firedZoomEnd) {
                firedZoomEnd = true;
                zoomEnd();
            } else {
                firedZoomEnd = false;
            }
        }
    }

    void setBounds(double bx1, double by1, double bx2, double by2) {
        this.hasBounds = true;
        this.bx1 = bx1;
        this.bx2 = bx2;
        this.by1 = by1;
        this.by2 = by2;

        this.xAnim = new DoubleAnimation(pxOffsetX, bx1, FRAME_COUNT);
        this.yAnim = new DoubleAnimation(pxOffsetY, by2, FRAME_COUNT);
    }

    void moveTo(double dx, double dy) {
        pxOffsetX = dx;
        pxOffsetY = dy;
        targetOffsetX = dx;
        targetOffsetY = dy;
    }

    void updateEngine() {
        xAnim.setStart(pxOffsetX);
        xAnim.setEnd(targetOffsetX);
        yAnim.setStart(pxOffsetY);
        yAnim.setEnd(targetOffsetY);

        updateZoom();
    }

    void updateZoom() {
        e.viewport = new CanvasViewportTransform(new Vector2(0.0, 0.0), new Vector2(pxOffsetX, GameEngine.HEIGHT - pxOffsetY));
        GameEngine.scale = e.viewport.scale = GameEngine.NSCALE * currentZoom;
        e.debugDraw = new SuperCanvasDraw(e.viewport, e.g);
    }


    void move() {
        bool updated = false;
        double speed = 5.05;

        if (Input.keys['space'].down) {
            e.setCanvasCursor('-webkit-grab');

            double dx = Input.getMouseDeltaX() * GameEngine.scale;
            double dy = Input.getMouseDeltaY() * GameEngine.scale;

            if (Input.isMouseLeftDown) {
                if (dx != 0.0) {
                    targetOffsetX -= dx;
                    updated = true;
                }
                if (dy != 0.0) {
                    targetOffsetY += dy;
                    updated = true;
                }
            }

            xAnim.setFrames(3000);
            yAnim.setFrames(3000);

            e.toggleBoundedCard(false);
        } else {
            e.toggleBoundedCard(true);

            if (/*Input.keys['w'].down || */Input.keys['arrow_up'].down) {
                targetOffsetY -= speed;
                updated = true;
            }

            if (/*Input.keys['a'].down || */Input.keys['arrow_left'].down) {
                targetOffsetX -= speed;
                updated = true;
            }

            if (/*Input.keys['s'].down || */Input.keys['arrow_down'].down) {
                targetOffsetY += speed;
                updated = true;
            }

            if (/*Input.keys['d'].down || */Input.keys['arrow_right'].down) {
                targetOffsetX += speed;
                updated = true;
            }
        }

        if (hasBounds) {
            checkTarget();
            updated = true;
        }

        if (updated) {
            updateEngine();
        }
    }

    void checkTarget() {
        if (mTargetX <= bx1 / GameEngine.NSCALE) mTargetX = bx1 / GameEngine.NSCALE;
        if (mTargetX + GameEngine.WIDTH >= bx2 / GameEngine.NSCALE) mTargetX = bx2 / GameEngine.NSCALE - GameEngine.WIDTH;

        if (mTargetY - GameEngine.HEIGHT <= by1 / GameEngine.NSCALE) mTargetY = by1 / GameEngine.NSCALE + GameEngine.HEIGHT;
        if (mTargetY >= by2 / GameEngine.NSCALE) mTargetY = by2 / GameEngine.NSCALE;
    }
}
