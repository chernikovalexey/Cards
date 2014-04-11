import "dart:html";

class Input {
  static num canvasX, canvasY;
  static num canvasWidth, canvasHeight;

  static num mouseX = 0.0, mouseY = 0.0;

  static bool isMouseDown = false;
  static bool isMouseClicked = false;
  
  static int wheelDirection = 0;

  Input() {
  }

  static void onMouseMove(MouseEvent event) {
    mouseX = (event.clientX - canvasX);
    mouseY = canvasHeight - (event.clientY - canvasY);
  }

  static void onMouseDown(MouseEvent event) {
    isMouseClicked = true;
    isMouseDown = true;
  }

  static void onMouseUp(MouseEvent event) {
    isMouseClicked = false;
    isMouseDown = false;
  }

  static void onMouseWheel(WheelEvent event) {
    wheelDirection = event.wheelDeltaY > 0 ? 1 : -1;
  }

  static void update() {
    isMouseClicked = false;
    wheelDirection = 0;
  }
}
