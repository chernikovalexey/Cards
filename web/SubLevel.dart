import "dart:html";
import "Bobbin.dart";
import 'package:box2d/box2d_browser.dart';
import "GameEngine.dart";
import "Sprite.dart";
import 'cards.dart';

class SubLevel {
    String name;

    List frames;

    List cards;

    int rating = 0;

    Body from;

    Body to;

    int staticBlocksRemaining;

    int dynamicBlocksRemaining;

    List<Body> obstacles = new List<Body>();

    List stars;

    GameEngine e;

    double x, y, w, h;

    Object fSprite, tSprite;

    Object levelData;

    int index;

    Function levelApplied;

    SubLevel(GameEngine e, Map l, int index) {
        this.index = index;
        this.e = e;
        this.name = l["name"];
        levelData = l;
        x = l['x'].toDouble() / GameEngine.scale;
        y = l['y'].toDouble() / GameEngine.scale;
        w = l['width'].toDouble() / GameEngine.scale;
        h = l['height'].toDouble() / GameEngine.scale;

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
            this.from = e.createPolygonShape(l["from"]["x"].toDouble() / GameEngine.scale,
            l["from"]["y"].toDouble() / GameEngine.scale, GameEngine.ENERGY_BLOCK_WIDTH, GameEngine.ENERGY_BLOCK_HEIGHT);
            this.from.userData = Sprite.from(e.world);
        }

        e.camera.setBounds(x, y, x + w, y + h);

        this.to = e.createPolygonShape(l["to"]["x"].toDouble() / GameEngine.scale,
        l["to"]["y"].toDouble() / GameEngine.scale, GameEngine.ENERGY_BLOCK_WIDTH, GameEngine.ENERGY_BLOCK_HEIGHT);
        this.to.userData = Sprite.to(e.world);

        for (var obstacle in l["obstacles"]) {
            Body o = e.createPolygonShape(obstacle["x"].toDouble() / GameEngine.scale,
            obstacle["y"].toDouble() / GameEngine.scale, obstacle["width"].toDouble() / GameEngine.scale,
            obstacle["height"].toDouble() / GameEngine.scale);
            o.userData = Sprite.byType(obstacle["type"]);
            obstacles.add(o);
        }

        e.from = this.from;
        e.to = this.to;
    }


    int getRating() {
        if (stars[0] >= e.cards.length) rating = 3;
        else if (stars[1] >= e.cards.length) rating = 2;
        else rating = 1;

        return rating;
    }

    void finish() {
        saveState();
        for(Body b in e.cards) {
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
        Function f = () {
            e.camera.setBounds(x, y, x + w, y + h);
            e.camera.mTargetX = x;
            e.camera.mTargetY = y;
            e.bobbin.list = this.frames;
            e.cards = this.cards;
            e.from = from;
            e.from.userData = fSprite;
            e.to = to;
            e.to.userData = tSprite;
            e.rewind();
            e.bobbin.rewindComplete = null;
            e.bobbin.rewindComplete = levelApplied;
        };

        if(e.physicsEnabled) {
            e.bobbin.rewindComplete = f;
            e.rewind();
        } else f();
    }
}
