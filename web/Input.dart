import "dart:html";
import "GameEngine.dart";
import "Camera.dart";

class Key {
  int code;
  bool down = false;
  Key(this.code);
}

class Input {
  static final Map<String, Key> keys = {
    'space': new Key(32),
    'z': new Key(90),
    'w': new Key(87),
    'a': new Key(65),
    's': new Key(83),
    'd': new Key(68)
  };

  static num canvasX, canvasY;
  static num canvasWidth, canvasHeight;
  static num mouseX = 0.0, mouseY = 0.0, prevMouseX = 0.0, prevMouseY = 0.0;

  static bool isAltDown = false;
  static bool isMouseLeftDown = false;
  static bool isMouseLeftClicked = false;
  static bool isMouseRightDown = false;
  static bool isMouseRightClicked = false;
  static int wheelDirection = 0;

  static Camera camera;

  static void setCamera(Camera c) {
    camera = c;
  }

  static void onMouseMove(MouseEvent event) {
    if (prevMouseX != mouseX) prevMouseX = mouseX;
    if (prevMouseY != mouseY) prevMouseY = mouseY;

    mouseX = (event.client.x - canvasX) / GameEngine.scale + camera.pxOffsetX /
        GameEngine.scale;
    mouseY = -(event.client.y - canvasY) / GameEngine.scale - camera.pxOffsetY /
        GameEngine.scale;
  }

  static void onMouseDown(MouseEvent event) {
    isMouseLeftClicked = event.which == 1;
    isMouseLeftDown = isMouseLeftClicked;
    isMouseRightClicked = event.which == 3;
    isMouseRightDown = isMouseRightClicked;
  }

  static void onMouseUp(MouseEvent event) {
    if (event.which == 1) {
      isMouseLeftClicked = false;
      isMouseLeftDown = false;
    } else if (event.which == 3) {
      isMouseRightDown = false;
      isMouseRightClicked = false;
    }
  }

  static void onContextMenu(MouseEvent event) {
    event.preventDefault();
  }

  static void onMouseWheel(WheelEvent event) {
    wheelDirection = event.wheelDeltaY > 0 ? 1 : -1;
  }

  static void toggle(KeyboardEvent event, bool down) {
    keys.forEach((String key, Key val) {
      if (val.code == event.keyCode) {
        val.down = down;
      }
    });
  }

  static void onKeyDown(KeyboardEvent event) {
    if (event.altKey) {
      isAltDown = true;
    }
    toggle(event, true);
  }

  static void onKeyUp(KeyboardEvent event) {
    toggle(event, false);
    isAltDown = false;
  }

  static void update() {
    isMouseLeftClicked = false;
    isMouseRightClicked = false;
    wheelDirection = 0;
  }

  static double getMouseDeltaX() {
    return mouseX - prevMouseX;
  }

  static double getMouseDeltaY() {
    return mouseY - prevMouseY;
  }
}
