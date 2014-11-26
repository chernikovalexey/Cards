import "dart:html";
import "Bobbin.dart";
import 'package:box2d/box2d_browser.dart';
import "GameEngine.dart";
import "Sprite.dart";
import 'cards.dart';
import 'Traverser.dart';
import 'EnergySprite.dart';
import 'Color4.dart';

class SubLevel {
    String name;

    List frames = new List();

    List cards = new List();

    List<Body> obstacles = new List<Body>();

    List stars;

    int attemptsUsed = 0;

    GameEngine e;

    Object fSprite, tSprite;

    Object levelData;

    Function levelApplied;

    double x, y, w, h;

    int rating = 0;

    int index;

    int staticBlocksRemaining;

    int dynamicBlocksRemaining;

    Body from;

    Body to;

    bool completed = false;

    SubLevel(GameEngine e, Map l, int index) {
        this.index = index;
        this.e = e;
        this.name = l["name"];
        levelData = l;
        x = l['x'].toDouble();
        y = l['y'].toDouble();
        w = l['width'].toDouble();
        h = l['height'].toDouble();

        this.staticBlocksRemaining = l["blocks"][0];
        this.dynamicBlocksRemaining = l["blocks"][1];
        this.stars = l['stars'];

        double boundsOffset = 0.0;
        if (index > 1) {
            x += e.to.position.x - GameEngine.ENERGY_BLOCK_WIDTH / 2;
            y += e.to.position.y - GameEngine.ENERGY_BLOCK_HEIGHT / 2;
            this.from = e.to;
            this.from.userData = Sprite.from(e.world);
//boundsOffset = x - (to.position.x - l["from"]["offset"].toDouble() / GameEngine.scale;);
        } else {
            this.from = e.createPolygonShape(l["from"]["x"].toDouble() / GameEngine.NSCALE, l["from"]["y"].toDouble() / GameEngine.NSCALE, GameEngine.ENERGY_BLOCK_WIDTH, GameEngine.ENERGY_BLOCK_HEIGHT);
            this.from.userData = Sprite.from(e.world);
        }

        e.camera.reset();
        e.camera.setBounds(x, y, x + w, y + h);

        this.to = e.createPolygonShape(l["to"]["x"].toDouble() / GameEngine.NSCALE, l["to"]["y"].toDouble() / GameEngine.NSCALE, GameEngine.ENERGY_BLOCK_WIDTH, GameEngine.ENERGY_BLOCK_HEIGHT);
        this.to.userData = Sprite.to(e.world);

        if (l["gravity"] != null) {
            e.world.setGravity(new Vector2(0.0, l["gravity"].toDouble()));
        }

        for (var obstacle in l["obstacles"]) {
            Body o;
            if (obstacle["type"] == 1 || obstacle["type"] == 5) {
                o = e.createPolygonShape(obstacle["x"].toDouble() / GameEngine.NSCALE, obstacle["y"].toDouble() / GameEngine.NSCALE, obstacle["width"].toDouble() / GameEngine.NSCALE, obstacle["height"].toDouble() / GameEngine.NSCALE, obstacle["type"] == 5);
            } else if (obstacle["type"] == 2 || obstacle["type"] == 6) {
                List<Vector2> points = new List();
                for (var p in obstacle["points"]) {
                    points.add(new Vector2(p['x'] / GameEngine.NSCALE, p['y'] / GameEngine.NSCALE));
                }
                o = e.createMultiShape(points, obstacle["type"] == 6);
            }

            Sprite s = Sprite.byType(1, e.world);
            o.userData = s;

            if (obstacle["type"] != 5 && obstacle["type"] != 6) {
                o.userData.isStatic = true;
            }

            obstacles.add(o);
        }

        e.from = this.from;
        e.to = this.to;
    }


    int getRating() {
        if (stars[0] >= e.cards.length) rating = 3; else if (stars[1] >= e.cards.length) rating = 2; else rating = 1;

        return rating;
    }

    void loadRating() {
        if (stars[0] >= cards.length) rating = 3; else if (stars[1] >= cards.length)rating = 2; else rating = 1;
    }

    void finish() {
        completed = true;
        saveState();
        for (Body b in e.cards) {
            b.type = BodyType.STATIC;
        }

        e.physicsEnabled = false;
        e.bobbin.erase();
        e.cards.clear();

        applyPhysicsLabelToButton();
    }

    void saveState() {
        cards = new List();
        cards.addAll(e.cards);

        frames = new List();
        frames.addAll(e.bobbin.list);

        from = e.from;
        to = e.to;
        fSprite = e.from.userData;
        tSprite = e.to.userData;
    }

    void fromData(GameEngine e) {
        e.bobbin.list = frames;
    }

    void enable(bool v) {
        for (Body b in cards) {
            b.userData.enabled = v;
        }

        e.from.userData.enabled = v;
        e.to.userData.enabled = v;
    }

    void apply() {
//analytics.levelStart(e.level.chapter, index);
        Function f = () {
            e.camera.setBounds(x, y, x + w, y + h);
            e.camera.mTargetX = x / GameEngine.scale;
            e.camera.mTargetY = y / GameEngine.scale;
            e.bobbin.list = this.frames;
            e.cards = this.cards;

            e.from = from;
            e.from.userData = Sprite.from(e.world);

            e.to = to;

            if (tSprite != null) e.to.userData = tSprite; else tSprite = e.to.userData;

            if (e.frontRewind) {
                applyRewindLabelToButton();
            } else {
                e.rewind();
                e.bobbin.rewindComplete = () {
                    e.bobbin.rewindComplete = null;
                    this.frames.clear();
                    if (levelApplied != null) levelApplied();
                    levelApplied = null;
                };
            }
        };

        if (e.physicsEnabled) {
            if (!e.frontRewind) {
                e.bobbin.rewindComplete = f;
                e.rewind();
            } else f();
        } else f();
    }

    void complete() {
        completed = true;
        for (Body b in cards) {
            (b.userData as EnergySprite).alwaysAnimate = true;
            (b.userData as EnergySprite).activate();
            (b.userData as EnergySprite).connectedToEnergy = true;
        }
    }

    void online(bool online) {
//print("SubLevel::online("+online.toString()+")");
        for (Body c in e.cards) {
            (c.userData as EnergySprite).makeSensor(!online, c);
        }

        (e.to.userData as EnergySprite).makeSensor(!online, e.to);
    }
}
