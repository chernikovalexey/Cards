import "dart:html";
import "GameEngine.dart";
import "Camera.dart";
import 'dart:js';

class Key {
    int code;
    bool down = false;
    bool clicked = false;

    Key(this.code);
}

class Input {
    static final Map<String, Key> keys = {
        'space': new Key(32), 'enter': new Key(13), 'delete': new Key(46), 'z': new Key(90), 'w': new Key(87), 'a': new Key(65), 's': new Key(83), 'd': new Key(68), 'n': new Key(78), 'p': new Key(80), '1': new Key(49), '2': new Key(50), 'esc': new Key(27), 'shift': new Key(16), 'ctrl': new Key(17), 'arrow_left': new Key(37), 'arrow_right': new Key(39), 'arrow_up': new Key(38), 'arrow_down': new Key(40), 'alt': new Key(18), 'q': new Key(81), 'e': new Key(69), 'c': new Key(67), 'v': new Key(86)
    };

    static num canvasX, canvasY;
    static num canvasWidth, canvasHeight;
    static num mouseX = 0.0, mouseY = 0.0, mouseDeltaX = 0.0, mouseDeltaY = 0.0;

    static bool isAltDown = false;
    static bool isAltClicked = false;
    static bool isCmdDown = false;
    static bool isCmdClicked = false;
    static bool isMouseLeftDown = false;
    static bool isMouseLeftClicked = false;
    static bool isMouseRightDown = false;
    static bool isMouseRightClicked = false;
    static int wheelDirection = 0;

    static bool mouseMoved = false;

    static WheelEvent wheelEvent;

    static Camera camera;

    static void setCamera(Camera c) {
        camera = c;
    }

    static void onMouseMove(MouseEvent event) {
        double prevMouseX = mouseX;
        double prevMouseY = mouseY;

        mouseX = (event.client.x - canvasX) / GameEngine.scale + camera.pxOffsetX / GameEngine.scale;
        mouseY = -(event.client.y - canvasY) / GameEngine.scale - camera.pxOffsetY / GameEngine.scale;
        mouseDeltaX = mouseX - prevMouseX;
        mouseDeltaY = mouseY - prevMouseY;

        mouseMoved = true;
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
            event.preventDefault();
        }
    }

    static void onContextMenu(MouseEvent event) {
        event.preventDefault();
    }

    static void onMouseWheel(WheelEvent event) {
        wheelEvent = event;
        wheelDirection = event.deltaY > 0 ? 1 : -1;
    }

    static void toggle(KeyboardEvent event, bool down) {
        keys.forEach((String key, Key val) {
            if (val.code == event.keyCode) {
                val.down = down;
                val.clicked = down;
            }
        });
    }

    static void onKeyDown(KeyboardEvent event) {
        if (event.altKey) {
            isAltDown = true;
            isAltClicked = true;
        }

        if (event.metaKey && context['Features']['is_macintosh']) {
            isCmdDown = true;
            isCmdClicked = true;
        }

        toggle(event, true);
        if (keyDown != null) keyDown(event);
    }

    static Function keyDown;

    static void onKeyUp(KeyboardEvent event) {
        toggle(event, false);

        isAltDown = false;
        isCmdDown = false;

        // Spike for Mac which is not detecting keyup of Z
        if (!event.metaKey && event.keyCode == 91 && context['Features']['is_macintosh']) {
            keys['z'].down = false;
            keys['z'].clicked = false;
        }
    }

    static void update() {
        isAltClicked = false;
        isCmdClicked = false;

        mouseMoved = false;

        isMouseLeftClicked = false;
        isMouseRightClicked = false;
        wheelDirection = 0;

        mouseDeltaX = 0.0;
        mouseDeltaY = 0.0;

        keys.forEach((String key, Key val) {
            val.clicked = false;
        });
    }

    static double getMouseDeltaX() {
        return mouseDeltaX;
    }

    static double getMouseDeltaY() {
        return mouseDeltaY;
    }

    static bool get mouseOverCanvas {
        return mouseX >= canvasX && mouseX <= canvasX + canvasWidth && mouseY >= canvasY && mouseY <= canvasY + canvasHeight;
    }

    static bool applied() {
        return (keys['ctrl'].down || isCmdDown) && keys['shift'].clicked || (keys['ctrl'].clicked || isCmdClicked) && keys['shift'].down;
    }

    static void attachSingleEscClickCallback(Function callback) {
        Input.keyDown = (KeyboardEvent e) {
            if (e.keyCode == Input.keys['esc'].code) {
                Input.keys['esc'].clicked = false;
                Input.keys['esc'].down = false;
                Input.keyDown = null;
                callback();
            }
        };
    }

    static void removeSingleEscClickCallback() {
        Input.keyDown = null;
    }
}
