import "Sprite.dart";
import "dart:html";
import "GameEngine.dart";
import 'package:box2d/box2d_browser.dart';


class EnergySprite extends Sprite {
    Body inner;

    EnergySprite(World w) {
        this.color = new Color3.fromRGB(255,250,200);

        BodyDef bd = new BodyDef();
        bd.position = new Vector2.zero();

        PolygonShape cs = new PolygonShape();
        cs.setAsBox(GameEngine.CARD_WIDTH / 2 - 0.01 , GameEngine.CARD_HEIGHT / 2 - 0.01);

        FixtureDef fd =  new FixtureDef();
        fd.isSensor = true;
        fd.shape = cs;

        inner = new Body(bd,w);
        inner.createFixture(fd);
        inner.userData = Sprite.innerEnergy();
    }

    void render(CanvasDraw g, Body b) {
        super.render(g,b);

        inner.setTransform(b.position.clone(), b.angle);

        super.render(g, inner);
    }


}
