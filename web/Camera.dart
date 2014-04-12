import "dart:html";
import 'package:box2d/box2d_browser.dart';
import "GameEngine.dart";
import "Input.dart";
import "DoubleAnimation.dart";
import "dart:math" as Math;

class Camera {
  static const int FRAME_COUNT = 20;
  static const double SPEED =5.5;

  double finalZoom = 1.0;
  double startZoom = 1.0;
  double currentZoom = 1.0;
  double targetOffsetX = 0.0, targetOffsetY = 0.0, offsetX = 0.0, offsetY = 0.0;

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
    offsetX = xAnim.next();
    offsetY = yAnim.next();

    move();

    if (!zoomAnimation.isFinished) {
      double zoom = zoomAnimation.next();
      currentZoom = zoom;
      updateEngine(zoom);

      if (!zoomAnimation.isFinished) currentZoom = finalZoom;
    }
  }

  void updateEngine(double zoom) {
    e.viewport = new CanvasViewportTransform(new Vector2(0.0, 0.0), new Vector2(
        offsetX, GameEngine.HEIGHT - offsetY));
    GameEngine.scale = e.viewport.scale = GameEngine.SCALE * zoom;

    e.debugDraw = new CanvasDraw(e.viewport, e.g);
    e.world.debugDraw = e.debugDraw;
  }

  void move() {
    bool updated = false;

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
          targetOffsetY -= dy;
          updated = true;
        }
      }
    }

    if (Input.keys['w'].down) {
      targetOffsetY -= SPEED;
      updated = true;
    }

    if (Input.keys['a'].down) {
      targetOffsetX -= SPEED;
      updated = true;
    }

    if (Input.keys['s'].down) {
      targetOffsetY += SPEED;
      updated = true;
    }

    if (Input.keys['d'].down) {
      targetOffsetX += SPEED;
      updated = true;
    }

    if (updated) {
      xAnim.setStart(offsetX);
      xAnim.setEnd(targetOffsetX);
      yAnim.setStart(offsetY);
      yAnim.setEnd(targetOffsetY);

      updateEngine(currentZoom);
    }
  }
}