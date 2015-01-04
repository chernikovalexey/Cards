import "dart:html";
import "Bobbin.dart";
import 'package:box2d/box2d_browser.dart';
import "GameEngine.dart";
import "Sprite.dart";
import 'cards.dart';
import 'Traverser.dart';
import 'EnergySprite.dart';
import 'Color4.dart';
import 'ParallaxManager.dart';

class SubLevel {
    String name;

    List frames = new List();
    List obstaclesFrames = new List();

    List cards = new List();

    List<Body> obstacles = new List<Body>();

    List stars;

    int attemptsUsed = 0;

    GameEngine e;

    Object fSprite, tSprite;

    Object levelData;

    Function levelApplied;

    double x, y, w, h;

    // Unique for each level
    int currentSpriteId = 0;
    int rating = 0;

    int index;

    int staticBlocksRemaining;

    int dynamicBlocksRemaining;

    int maxStaticBlocks, maxDynamicBlocks;

    Body from;

    Body to;

    bool completed = false;

    void alignCamera() {
        e.camera.reset();
        e.camera.setBounds(x, y, x + w, y + h);
    }

    SubLevel(GameEngine e, Map l, int index, [bool further = false]) {
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
        this.maxStaticBlocks = l['blocks'][0];
        this.maxDynamicBlocks = l['blocks'][1];
        this.stars = l['stars'];

        double boundsOffset = 0.0;
        if (index > 1) {
            // Get from cube from the previous level, not from the engine!
            this.from = e.level.subLevels[index - 2].to;
            this.from.userData = Sprite.from(e.world, !further);
        } else {
            this.from = e.createPolygonShape(l["from"]["x"].toDouble() / GameEngine.NSCALE, l["from"]["y"].toDouble() / GameEngine.NSCALE, GameEngine.ENERGY_BLOCK_WIDTH, GameEngine.ENERGY_BLOCK_HEIGHT);
            this.from.userData = Sprite.from(e.world, !further);
        }

        alignCamera();

        this.to = e.createPolygonShape(l["to"]["x"].toDouble() / GameEngine.NSCALE, l["to"]["y"].toDouble() / GameEngine.NSCALE, GameEngine.ENERGY_BLOCK_WIDTH, GameEngine.ENERGY_BLOCK_HEIGHT);
        this.to.userData = Sprite.to(e.world);

        if (l["gravity"] != null) {
            double gravity = l["gravity"].toDouble();
            e.world.setGravity(new Vector2(0.0, gravity));

            if (gravity > 0.0) {
                parallax.modifier = ParallaxManager.UP;
            } else {
                parallax.modifier = ParallaxManager.DOWN;
            }
        }

        print("Parsing the obstacle of level #" + index.toString());

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

            int type = 1;
            if (obstacle['type'] == 5 || obstacle['type'] == 6) {
                type = 4;
            }
            Sprite s = Sprite.byType(type, e.world);
            o.userData = s;
            o.userData.id = ++currentSpriteId;

            if (obstacle["type"] != 5 && obstacle["type"] != 6) {
                o.userData.isStatic = true;
            }

            obstacles.add(o);

            print("after creating: x=" + o.position.x.toString() + ", y=" + o.position.y.toString());
        }

        if (!further) {
            e.from = this.from;
            e.to = this.to;
        }
    }


    int getRating() {
        if (stars[0] >= e.cards.length) rating = 3; else if (stars[1] >= e.cards.length) rating = 2; else rating = 1;

        return rating;
    }

    void loadRating() {
        if (stars[0] >= cards.length) rating = 3; else if (stars[1] >= cards.length)rating = 2; else rating = 1;
    }

    bool finish() {
        // Can't finish an empty level
        if (e.cards.isEmpty) {
            return false;
        }

        completed = true;
        saveState();
        for (Body b in e.cards) {
            b.type = BodyType.STATIC;
        }

        e.physicsEnabled = false;
        e.bobbin.erase();
        e.cards.clear();

        applyPhysicsLabelToButton();

        return true;
    }

    void saveState() {
        cards = new List();
        cards.addAll(e.cards);

        frames = new List();
        frames.addAll(e.bobbin.list);

        obstaclesFrames = new List();
        obstaclesFrames.addAll(e.obstaclesBobbin.list);

        from = e.from;
        to = e.to;
        fSprite = e.from.userData;
        tSprite = e.to.userData;
    }

    void fromData(GameEngine e) {
        e.bobbin.list = frames;
        e.obstaclesBobbin.list = obstaclesFrames;
    }

    void enable(bool v) {
        for (Body b in cards) {
            b.userData.enabled = v;
        }

        from.userData.enabled = v;
        to.userData.enabled = v;
    }

    void apply() {
//analytics.levelStart(e.level.chapter, index);

        print("Applying: " + index.toString());

        Function f = () {
            e.camera.setBounds(x, y, x + w, y + h);
            e.camera.mTargetX = x / GameEngine.scale;
            e.camera.mTargetY = y / GameEngine.scale;
            e.bobbin.list = frames;
            e.cards = cards;

            print("Frames length: " + frames.length.toString());

            e.obstaclesBobbin.list = obstaclesFrames;

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
                    this.obstaclesFrames.clear();

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
            if (!b.userData.isStatic && b.userData.energy > 0.5) {
                (b.userData as EnergySprite).alwaysAnimate = true;
                (b.userData as EnergySprite).activate();
                (b.userData as EnergySprite).connectedToEnergy = true;
            }
        }
    }

    void online(bool online, [bool full = false]) {
        for (Body c in this.cards) {
            (c.userData as EnergySprite).makeSensor(!online, c);
        }

        if (full && this.from != e.level.current.to) {
            (this.from.userData as EnergySprite).makeSensor(!online, this.from);
        }

        (this.to.userData as EnergySprite).makeSensor(!online, this.to);
    }
}
