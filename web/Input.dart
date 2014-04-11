import "dart:html";

class Input {
  static num canvasX, canvasY;
  static num canvasWidth, canvasHeight;

  static num mouseX = 0.0, mouseY = 0.0;
  static bool isMouseDown = false;

  Input() {
  }

  static void onMouseMove(MouseEvent e) {
    mouseX = (e.clientX - canvasX);
    mouseY = canvasHeight - (e.clientY - canvasY);
  }

  static void onMouseDown(MouseEvent e) {
    isMouseDown = true;
  }

  static void onMouseUp(MouseEvent e) {
    isMouseDown = false;
  }
}
