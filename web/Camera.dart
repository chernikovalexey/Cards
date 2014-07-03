import "dart:html";
import 'package:box2d/box2d_browser.dart';
import "GameEngine.dart";
import "Input.dart";
import 'Sprite.dart';
import "DoubleAnimation.dart";
import "dart:math" as Math;
import "SuperCanvasDraw.dart";

class Camera {
  static const int FRAME_COUNT = 10;

  bool hasBounds = false;

  double finalZoom = 1.0;
  double startZoom = 1.0;
  double currentZoom = 1.0;
  double targetOffsetX = 0.0, targetOffsetY = 0.0, pxOffsetX = 0.0, pxOffsetY =
      0.0;
  double bx1, by1, bx2, by2;

  double get mTargetX => targetOffsetX / GameEngine.scale;
  double get mTargetY => -targetOffsetY / GameEngine.scale;

  bool firedMovingEnd = true;
  Function movingEnd = () {};

  set mTargetX(double offset) {
    this.targetOffsetX = offset * GameEngine.scale;
    updateEngine(currentZoom);
  }

  set mTargetY(double offset) {
    this.targetOffsetY = -offset * GameEngine.scale;
    updateEngine(currentZoom);
  }

  DoubleAnimation zoomAnimation = new DoubleAnimation(1.0, 1.0, 5);
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
    zoomAnimation = new DoubleAnimation(currentZoom, finalZoom, FRAME_COUNT);
  }

  void update(num delta) {
    double nx = xAnim.next();
    double ny = yAnim.next();

    double ppx = pxOffsetX;
    double ppy = pxOffsetY;
    
    pxOffsetX = nx;
    pxOffsetY = ny;
    
    if(ppx == pxOffsetX && ppy == pxOffsetY && !firedMovingEnd) {
      firedMovingEnd = true;
      movingEnd();
    } else if(ppx != pxOffsetX || ppy != pxOffsetY) {
      firedMovingEnd = false;
    }

    if (xAnim.isFinished) xAnim.setFrames(FRAME_COUNT);
    if (yAnim.isFinished) yAnim.setFrames(FRAME_COUNT);

    move();

    if (!zoomAnimation.isFinished) {
      double zoom = zoomAnimation.next();
      currentZoom = zoom;
      updateEngine(zoom);

      if (!zoomAnimation.isFinished) currentZoom = finalZoom;
    }
  }

  void setBounds(double bx1, double by1, double bx2, double by2) {
    this.hasBounds = true;
    this.bx1 = bx1;
    this.bx2 = bx2;
    this.by1 = by1;
    this.by2 = by2;

    this.xAnim = new DoubleAnimation(pxOffsetX, bx1, 100);
    this.yAnim = new DoubleAnimation(pxOffsetY, by2, 100);
  }

  void moveTo(double dx, double dy) {
    pxOffsetX = dx;
    pxOffsetY = dy;
  }

  void updateEngine(double zoom) {
    xAnim.setStart(pxOffsetX);
    xAnim.setEnd(targetOffsetX);
    yAnim.setStart(pxOffsetY);
    yAnim.setEnd(targetOffsetY);

    e.viewport = new CanvasViewportTransform(new Vector2(0.0, 0.0), new Vector2(
        pxOffsetX, GameEngine.HEIGHT - pxOffsetY));
    GameEngine.scale = e.viewport.scale = GameEngine.NSCALE * zoom;

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

      e.toggleBoundedCard(false);
    } else {
      e.toggleBoundedCard(true);
    }

    double ptx = targetOffsetX;
    double pty = targetOffsetY;

    if (Input.keys['w'].down) {
      targetOffsetY -= speed;
      updated = true;
    }

    if (Input.keys['a'].down) {
      targetOffsetX -= speed;
      updated = true;
    }

    if (Input.keys['s'].down) {
      targetOffsetY += speed;
      updated = true;
    } 

    if (Input.keys['d'].down) {
      targetOffsetX += speed;
      updated = true;
    }

    if (hasBounds) {
      checkTarget();
      updated = true;
    }

    if (updated) {
      updateEngine(currentZoom);
    }
  }
 
  void checkTarget() {
    if (mTargetX <= bx1/GameEngine.NSCALE) mTargetX = bx1/GameEngine.NSCALE;
    if (mTargetX + GameEngine.WIDTH >= bx2/GameEngine.NSCALE) mTargetX = bx2/GameEngine.NSCALE - GameEngine.WIDTH;
    
    if (mTargetY - GameEngine.HEIGHT <= by1/GameEngine.NSCALE) mTargetY = by1/GameEngine.NSCALE + GameEngine.HEIGHT;
    if (mTargetY >= by2/GameEngine.NSCALE) mTargetY = by2/GameEngine.NSCALE;
  }
}
