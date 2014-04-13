import "dart:html";
import 'package:box2d/box2d_browser.dart';
import "GameEngine.dart";
import "Input.dart";
import 'Sprite.dart';
import "DoubleAnimation.dart";
import "dart:math" as Math;

class Camera {
  static final int FRAME_COUNT = 20;

  bool hasBounds = false;

  double finalZoom = 1.0;
  double startZoom = 1.0;
  double currentZoom = 1.0;
  double targetOffsetX = 0.0, targetOffsetY = 0.0, pxOffsetX = 0.0, pxOffsetY = 0.0;
  double bx1, by1, bx2, by2;

  double get mTargetX => targetOffsetX / GameEngine.scale;
  double get mTargetY => -targetOffsetY / GameEngine.scale;

  set mTargetX(double offset) {
    this.targetOffsetX = offset * GameEngine.scale;
    updateEngine(currentZoom);
  }

  set mTargetY(double offset) {
    this.targetOffsetY = -offset * GameEngine.scale;
    updateEngine(currentZoom);
  }

  DoubleAnimation zoomAnimation = new DoubleAnimation(1.0, 1.0, FRAME_COUNT);
  DoubleAnimation xAnim = new DoubleAnimation(0.0, 0.0, FRAME_COUNT);
  DoubleAnimation yAnim = new DoubleAnimation(0.0, 0.0, FRAME_COUNT);

  GameEngine e;

  Camera(GameEngine e) {
    this.e = e;
    Input.setCamera(this);
  }

  void beginZoom(double finalZoom, double currentZoom) {
    this.finalZoom = finalZoom;
    this.startZoom = currentZoom;
    zoomAnimation = new DoubleAnimation(currentZoom, finalZoom, FRAME_COUNT);
  }

  void update(num delta) {
    pxOffsetX = targetOffsetX;
  pxOffsetY = targetOffsetY;
    // pxOffsetX = xAnim.next();
    //pxOffsetY = yAnim.next();

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
  }
  
  void updateCameraMovement() {
    print("upd");
    xAnim.setStart(pxOffsetX);
    xAnim.setEnd(targetOffsetX);
//  xAnim.setFrame(0);
  yAnim.setStart(pxOffsetY);
  yAnim.setEnd(targetOffsetY);
  //yAnim.setFrame(0);
  }
  
  void updateEngine(double zoom) {
    

    e.viewport = new CanvasViewportTransform(new Vector2(0.0, 0.0), new Vector2(
        pxOffsetX, GameEngine.HEIGHT - pxOffsetY));
    GameEngine.scale = e.viewport.scale = GameEngine.NSCALE * zoom;

    e.debugDraw = new CanvasDraw(e.viewport, e.g);
    e.world.debugDraw = e.debugDraw;
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

      (e.bcard.b.userData as Sprite).isHidden = true;
    } else {
      (e.bcard.b.userData as Sprite).isHidden = false;
    }

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

    updateCameraMovement();

  }
}
