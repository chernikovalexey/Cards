import "dart:html";
import 'package:box2d/box2d_browser.dart';
import "GameEngine.dart";
import "Input.dart";
import 'Sprite.dart';
import "DoubleAnimation.dart";
import "dart:math" as Math;

class Camera {
  static const int CAMERA_MOVING_FRAMES = 20;
  static const int LEVEL_CHANGE_FRAMES = 20000;

  bool hasBounds = false;

  double finalZoom = 1.0;
  double startZoom = 1.0;
  double currentZoom = 1.0;
  double targetOffsetX = 0.0, targetOffsetY = 0.0, offsetX = 0.0, offsetY = 0.0;
  double bx1, by1, bx2, by2;

  double get mOffsetX => offsetX / GameEngine.scale;
  double get mOffsetY => offsetY / GameEngine.scale;
  double get mTargetX => targetOffsetX / GameEngine.scale;
  double get mTargetY => -targetOffsetY / GameEngine.scale;

  set mOffsetX(double offset) {
    this.offsetX = offset * GameEngine.scale;
    updateEngine(currentZoom);
  }

  set mOffsetY(double offset) {
    this.offsetY = -offset * GameEngine.scale;
    updateEngine(currentZoom);
  }

  set mTargetX(double offset) {
    this.targetOffsetX = offset * GameEngine.scale;
    updateEngine(currentZoom);
  }

  set mTargetY(double offset) {
    this.targetOffsetY = -offset * GameEngine.scale;
    updateEngine(currentZoom);
  }

  DoubleAnimation zoomAnimation = new DoubleAnimation(1.0, 1.0,
      CAMERA_MOVING_FRAMES);
  DoubleAnimation xAnim = new DoubleAnimation(0.0, 0.0, CAMERA_MOVING_FRAMES);
  DoubleAnimation yAnim = new DoubleAnimation(0.0, 0.0, CAMERA_MOVING_FRAMES);

  GameEngine e;

  Camera(GameEngine e) {
    this.e = e;
    Input.setCamera(this);
  }

  void beginZoom(double finalZoom, double currentZoom) {
    this.finalZoom = finalZoom;
    this.startZoom = currentZoom;
    zoomAnimation = new DoubleAnimation(currentZoom, finalZoom,
        CAMERA_MOVING_FRAMES);
  }

  void update(num delta) {
    double ny = yAnim.next();
    print(ny);
    //offsetX = xAnim.next();
    //offsetY = ny;

    offsetX = targetOffsetX;
    offsetY = targetOffsetY;
    
    //offsetX += (targetOffsetX - offsetX) * delta;
    //offsetY += (targetOffsetY - offsetY) * delta;
    
    //if (xAnim.isFinished) xAnim.setFrames(CAMERA_MOVING_FRAMES);
    //if (yAnim.isFinished) yAnim.setFrames(CAMERA_MOVING_FRAMES);

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
    
  }

  void updateEngine(double zoom) {
    //print((offsetX).toString() + ", " + (offsetY).toString());
    xAnim.setStart(offsetX);
        xAnim.setEnd(targetOffsetX);
        yAnim.setStart(offsetY);
        yAnim.setEnd(targetOffsetY);
        
    double newScale = GameEngine.NSCALE * zoom;
    e.viewport = new CanvasViewportTransform(new Vector2(0.0, 0.0), new Vector2(
        offsetX, GameEngine.HEIGHT - offsetY));
    GameEngine.scale = e.viewport.scale = newScale;

    e.debugDraw = new CanvasDraw(e.viewport, e.g);
    e.world.debugDraw = e.debugDraw;
  }

  void move() {
    bool updated = false;
    double speed = 5.05;

    if (Input.keys['space'].down) {
      e.setCanvasCursor('-webkit-grab');

      if (Input.isMouseLeftDown) {
        if (Input.getMouseDeltaX() != 0.0) {
          mTargetX -= Input.getMouseDeltaX();
          updated = true;
        }
        if (Input.getMouseDeltaY() != 0.0) {
          mTargetY -= Input.getMouseDeltaY();
          updated = true;
        }
      }

      e.toggleBoundedCard(false);
    } else {
      e.toggleBoundedCard(true);
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

    if (hasBounds) {
      if (mTargetX <= bx1) mTargetX = bx1;
      if (mTargetX + GameEngine.WIDTH >= bx2) mTargetX = bx2 - GameEngine.WIDTH;
      if (mTargetY - GameEngine.HEIGHT <= by1) mTargetY = by1 +
          GameEngine.HEIGHT;
      if (mTargetY >= by2) mTargetY = by2;

      updated = true;
    }
    
    //print(xAnim.start.toString() + ", " + xAnim.end.toString());

    if (updated) {
      updateEngine(currentZoom);
    }
  }
}
