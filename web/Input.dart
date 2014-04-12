import "dart:html";
import "GameEngine.dart";
import "Camera.dart";

class Input {
  static final LEFT = 37;
  static final int A = 65;
  static final int RIGHT = 39;
  static final int D = 68;
  static final int UP = 38;
  static final int DOWN = 40;
  static final int NUM_PLUS = 107;
  static final int PLUS = 187;
  static final int NUM_MINUS = 109;
  static final int MINUS = 189;

  static num canvasX, canvasY;
  static num canvasWidth, canvasHeight;
  static num mouseX = 0.0, mouseY = 0.0;

  static bool isMouseLeftDown = false;
  static bool isMouseLeftClicked = false;
  static bool isMouseRightDown = false;
  static bool isMouseRightClicked = false;
  static bool leftArrowDown = false;
  static bool rightArrowDown = false;
  static bool upArrowDown = false;
  static bool downArrowDown = false;
  static bool plusDown = false;
  static bool minusDown = false;
  static int wheelDirection = 0;

  static Camera camera;

  Input() {
  }

    static void setCamera(Camera c) {
        camera = c;
    }

  static void onMouseMove(MouseEvent event) {
    mouseX = (event.clientX - canvasX) / GameEngine.scale + camera.offsetX / GameEngine.scale;
    mouseY = -(event.clientY - canvasY) / GameEngine.scale - camera.offsetY / GameEngine.scale;
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

  static void onKeyDown(KeyboardEvent event) {
    if (event.keyCode == LEFT) {
      leftArrowDown = true;
    } else if (event.keyCode == RIGHT) {
      rightArrowDown = true;
    } else if (event.keyCode == DOWN) {
      downArrowDown = true;
    } else if (event.keyCode == LEFT) {
      leftArrowDown = true;
    } else if (event.keyCode == PLUS || event.keyCode == NUM_PLUS) {
      plusDown = true;
    } else if (event.keyCode == MINUS || event.keyCode == NUM_MINUS) {
      minusDown = true;
    } else if (event.keyCode == A) {
      wheelDirection = 1;
    } else if (event.keyCode == D) {
      wheelDirection = -1;
    } else if (event.keyCode == UP) {
      upArrowDown = true;
    }
  }

  static void onKeyUp(KeyboardEvent event) {
    if (event.keyCode == LEFT) {
      leftArrowDown = false;
    } else if (event.keyCode == RIGHT) {
      rightArrowDown = false;
    } else if (event.keyCode == PLUS || event.keyCode == NUM_PLUS) {
      plusDown = false;
    } else if (event.keyCode == MINUS || event.keyCode == NUM_MINUS) {
      minusDown = false;
    } else if (event.keyCode == A) {
      wheelDirection = 0;
    } else if (event.keyCode == D) {
      wheelDirection = 0;
    } else if (event.keyCode == UP) {
      upArrowDown = false;
    } else if (event.keyCode == DOWN) {
      downArrowDown = false;
    }
  }

  static void update() {
    isMouseLeftClicked = false;
    isMouseRightClicked = false;
    wheelDirection = 0;
  /*  rightArrowDown = false;
    leftArrowDown = false;
    upArrowDown = false;
    downArrowDown = false;*/

    plusDown = false;
    minusDown = false;
  }
}
