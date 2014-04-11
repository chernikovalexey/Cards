import "dart:html";
import "GameEngine.dart";

class Input {
  static num canvasX, canvasY;
  static num canvasWidth, canvasHeight;

  static num mouseX = 0.0, mouseY = 0.0;

  static bool isMouseLeftDown = false;
  static bool isMouseLeftClicked = false;
  static bool isMouseRightDown = false;
  static bool isMouseRightClicked = false;
  static int wheelDirection = 0;

  Input() {
  }

  static void onMouseMove(MouseEvent event) {
    mouseX = (event.clientX - canvasX) / GameEngine.SCALE;
    mouseY = -(event.clientY - canvasY) / GameEngine.SCALE;
  }

  static void onMouseDown(MouseEvent event) {
    bool isLeft = event.which == 1;
    bool isRight = event.which == 3;
    isMouseLeftClicked = isLeft;
    isMouseLeftDown = isLeft;
    isMouseRightClicked = isRight;
    isMouseRightDown = isRight;
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

  static void update() {
    isMouseLeftClicked = false;
    isMouseRightClicked = false;
    wheelDirection = 0;
  }
}
