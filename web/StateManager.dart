import 'dart:html';
import 'Input.dart';

abstract class State {
  void start();
  void update(num delta);
  void render();
}

class StateManager {
  List<State> states = new List<State>();

  num lastStepTime = 0;

  CanvasRenderingContext2D g;

  StateManager(this.g) {
    run();
  }

  void addState(State state) {
    states.add(state);
    state.start();
  }

  void removeState(State state) {
      states.remove(state);
  }

  void run() {
    window.requestAnimationFrame(step);
  }

  void step(num time) {
    num delta = time - this.lastStepTime;

    g.setFillColorRgb(0, 0, 0);
    g.fillRect(0, 0, Input.canvasWidth, Input.canvasHeight);

    for (State state in states) {
      state.update(delta);
      state.render();
    }

    this.lastStepTime = time;

    run();
  }
}
