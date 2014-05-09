import 'dart:html';
import 'dart:math';
import 'Input.dart';

class Star {
  bool extinct = false;
  double x = 0.0, y = -25.0;
  double speed;
  double opacity;

  Star(this.x, this.speed, this.opacity);

  void update(num delta) {
    y += speed;

    if (y > Input.canvasHeight) {
      extinct = true;
    }
  }

  void render(CanvasRenderingContext2D g) {
    g.fillStyle = 'rgba(255, 255, 255, '+opacity.toString()+')';
    g.fillRect(x, y, 2, 2);
  }
}

class ParallaxManager {
  CanvasRenderingContext2D g;

  num lastStepTime = 0;
  int layers, amount;

  List<Star> stars = new List<Star>();

  ParallaxManager(this.g, this.layers, this.amount) {
    generateLacking();
    run();
  }

  void generateLacking() {
    Random random = new Random();

    for (int i = 0; i < amount - stars.length; ++i) {
      int layer = random.nextInt(layers);
      var data = getStarData(random, layer,layers);
      Star star = new Star(random.nextDouble() * Input.canvasWidth, data[0], data[1]);
      stars.add(star);
    }
  }
  
  static List getStarData(Random random, int layer, int layers) {
    return [random.nextDouble() - layer/layers, layer/layers * 1.2];
  }

  void run() {
    window.animationFrame.then(step);
  }

  void step(num time) {
    num delta = time - this.lastStepTime;

    update(delta);

    g.setFillColorRgb(0, 0, 0);
    render();
    this.lastStepTime = time;

    run();
  }

  void update(num delta) {
    for (Star star in stars) {
      star.update(delta);

      if (star.extinct) {
        stars.remove(star);
      }
    }

    generateLacking();
    
    print("stars.length="+stars.length.toString());
  }

  void render() {
    g.fillStyle = 'rgba(0, 0, 0, 1)';
    g.fillRect(0, 0, Input.canvasWidth, Input.canvasHeight);
    for (Star star in stars) {
      star.render(g);
    }
  }
}
