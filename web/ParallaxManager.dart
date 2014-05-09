import 'dart:html';
import 'dart:math';
import 'Input.dart';
import 'StateManager.dart';
import 'GameEngine.dart';
import 'package:box2d/box2d_browser.dart';

Random random = new Random();

Color3 YELLOW = new Color3.fromRGB(254, 251, 224);
Color3 CYAN = new Color3.fromRGB(125, 165, 253);

class Star {
  bool extinct = false;
  double x = 0.0, y = 0.0;
  double speed;
  double opacity;
  int size = 2;
  Color3 color = YELLOW;

  Star(this.x, this.y, this.speed, this.opacity) {

    // Add some diversity
    if (random.nextInt(128) % 2 == 0) {
      color = CYAN;
    }

    if (random.nextInt(128) % 2 == 0) {
      size = 1;
    }
  }

  void update(num delta) {
    y += speed;

    if (y > Input.canvasHeight) {
      extinct = true;
    }
  }

  void render(CanvasRenderingContext2D g) {
    g.fillStyle = 'rgba(' + color.x.toString() + ', ' + color.y.toString() +
        ', ' + color.z.toString() + ', ' + opacity.toString() + ')';
    g.fillRect(x, y, size, size);
  }
}

class ParallaxManager extends State {
  GameEngine engine;
  CanvasRenderingContext2D g;

  num lastStepTime = 0;
  int layers, amount;

  List<Star> stars = new List<Star>();

  ParallaxManager(this.engine, this.g, this.layers, this.amount);

  static List getStarData(Random random, int layer, int layers) {
    double speed = (random.nextDouble() - layer / layers) * 0.35 / 1.5;
    while (speed < 0.01) speed += random.nextDouble() / 10;

    double opacity = speed + speed * layer / layers;
    while (opacity > 0.25) opacity -= random.nextDouble() / 10;

    return [speed, opacity];
  }

  @override
  void start([Map params]) {}

  @override
  void update(num delta) {
    if (!engine.ready || (engine.ready && engine.physicsEnabled)) {
      List<Star> _stars = new List<Star>();
      _stars.addAll(stars);
      for (Star star in _stars) {
        star.update(delta);

        if (star.extinct) {
          stars.remove(star);
        }
      }

      // Generate lacking stars
      for (int i = 0; i < amount - stars.length; ++i) {
        int layer = random.nextInt(layers);
        var data = getStarData(random, layer, layers);
        Star star = new Star(random.nextDouble() * Input.canvasWidth,
            random.nextDouble() * Input.canvasHeight, data[0], data[1]);
        stars.add(star);
      }
    }
  }

  @override
  void render() {
    g.fillStyle = 'rgba(0, 0, 0, 1)';
    g.fillRect(0, 0, Input.canvasWidth, Input.canvasHeight);
    for (Star star in stars) {
      star.render(g);
    }
  }
}
