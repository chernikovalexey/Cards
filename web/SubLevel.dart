import "dart:html";
import "Bobbin.dart";
import 'package:box2d/box2d_browser.dart';
import "GameEngine.dart";
import "Sprite.dart";

class SubLevel {
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

    Object fSprite, tSprite;

    SubLevel(GameEngine e, Object l, int index) {
        this.e = e;
        double x = l['x'].toDouble() / GameEngine.scale;
        double y = l['y'].toDouble() / GameEngine.scale;;
        double w = l['width'].toDouble() / GameEngine.scale;;
        double h = l['height'].toDouble() / GameEngine.scale;;

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
        print(stars[0]);
        if(stars[0] >= e.cards.length) rating = 3;
        else if(stars[1] >= e.cards.length) rating = 2;
        else rating = 1;

        return rating;
    }

    void finish() {
        for(Body b in e.cards) {
            b.type = BodyType.STATIC;
            b.userData.appliesToCurrentLevel = false;
            var btn = querySelector("#toggle-physics");
            btn.text= "Apply physics";
            btn.classes.toggle("rewind");

        }
        e.physicsEnabled = false;
        e.bobbin.erase();
        e.cards.clear();
    }

    void fromData(GameEngine e) {
        e.bobbin.list = frames;
    }
}
