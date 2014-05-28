import "Sprite.dart";
import "dart:html";
import "GameEngine.dart";
import 'package:box2d/box2d_browser.dart';
import "dart:math" as Math;
import "Color4.dart";
import "SuperCanvasDraw.dart";
import "GlowSprite.dart";
import "DoubleAnimation.dart";


class EnergySprite extends Sprite {
  static Color4 baseColor = new Color4.fromRGBA(234, 140, 64, 1.0);
  Body inner;

  List<GlowSprite> effects = new List();

  int glowBorders = 1;
  int glowAdd = 1;
  int frame = 0;
  
  double energyStep = .05;

  bool alwaysAnimate = false;

  Body current;
  bool isCard = true;

  EnergySprite(World w, [this.isCard = true]) {
    energySupport = true;

    double k = 1.0;
    if (isCard) k = 1.65;
    effects.add(new GlowSprite(.75, .95, 0.01 / k));
    effects.add(new GlowSprite(.5, .75, 0.02 / k));
    effects.add(new GlowSprite(.2, .45, 0.03 / k));
    effects.add(new GlowSprite(.1, .25, 0.04 / k));

    this.color = new Color4.fromColor4(baseColor);
  }

  int sign(double x) {
    return x > 0 ? 1 : -1;
  }

  void activate() {
    active = true;
  }

  void deactivate() {
    active = false;
    connectedToEnergy = false;
  }

  @override
  void render(SuperCanvasDraw g, Body b) {

    if (energy < 0) energy = 0.0; else if (energy > 1) energy = 1.0;
    current = b;


    if (isHidden) return;

    super.render(g, b);

    frame++;

    if (!active && energy <= 0) return;

    if (active && energy <= 1 - energyStep) {
      energy += energyStep;
    } else if (active) {
      energy = 1.0;
    } else if (!active && energy >= energyStep) {
      energy -= energyStep;
    } else {
      energy = 0.0;
    }

    for (GlowSprite gs in effects) gs.render(g, b);

  }

  void update(GameEngine e) {
    if (!e.physicsEnabled) return;
    if (active && !connectedToEnergy) deactivate(); else if (!active &&
        connectedToEnergy) activate();
  }

  bool isFull() {
    return energy >= 1 - energyStep;
  }
}
