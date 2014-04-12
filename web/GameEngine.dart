import 'dart:html';
import 'dart:math' as Math;
import 'package:box2d/box2d_browser.dart';
import 'cards.dart';
import "Input.dart";
import "BoundedCard.dart";
import "Bobbin.dart";
import "CardContactListener.dart";
import 'Camera.dart';
import 'Sprite.dart';

class GameEngine {
  static const double SCALE = 85.0;

  static double WIDTH = 800.0 / SCALE;
  static double HEIGHT = 600.0 / SCALE;
  static double CARD_WIDTH = 45.0 / SCALE;
  static double CARD_HEIGHT = 2.5 / SCALE;
  static const double GRAVITY = -10.0;

  num lastStepTime = 0;
  static double scale = SCALE;
  bool physicsEnabled = false;

  World world;
  CardContactListener contactListener;
  CanvasRenderingContext2D g;
  ViewportTransform viewport;
  DebugDraw debugDraw;
  BoundedCard bcard;
  Bobbin bobbin;
  Camera camera;

  Body from, to;
  List<Body> cards = new List<Body>();

  bool isRewinding = false;
  double cardDensity = 0.1, cardFriction = 0.1, cardRestitution = 0.01;
  double currentZoom = 1.0;

    GameEngine(CanvasRenderingContext2D g)
    {
        this.g = g;
        camera = new Camera(this);

        initializeWorld();
        initializeCanvas();
    }

    void initializeCanvas()
    {
        viewport = new CanvasViewportTransform(new Vector2(0.0, 0.0), new Vector2(0.0, HEIGHT));
        viewport.scale = scale;

        debugDraw = new CanvasDraw(viewport, g);
        world.debugDraw = debugDraw;
    }

    void initializeWorld()
    {
        this.contactListener = new CardContactListener(this);
        this.world = new World(new Vector2(0.0, GRAVITY), true, new DefaultWorldPool());

        world.contactListener = contactListener;

        this.bobbin = new Bobbin((){});
        createPolygonShape(0.0, -HEIGHT * 0.99, WIDTH, HEIGHT * 0.01).userData = Sprite.ground();

        this.bcard = new BoundedCard(this);
        this.from = createPolygonShape(100.0 / scale, -HEIGHT + 50 / scale + HEIGHT * 0.02, 50.0 / scale, 50.0 / scale);
        this.from.userData = Sprite.from();
        this.to = createPolygonShape(WIDTH - 100 / scale, -HEIGHT / 2 + 75 / scale, 50.0 / scale, 50.0 / scale);
        this.to.userData = Sprite.to();
    }

    void setCanvasCursor(String cursor) {
        canvas.style.cursor = cursor;
    }
    
    Body createPolygonShape(double x, double y, double width, double height)
    {
        PolygonShape sd = new PolygonShape();
        sd.setAsBox(width, height);

        FixtureDef fd = new FixtureDef();
        fd.shape = sd;
        fd.friction = 0.7;

        BodyDef bd = new BodyDef();
        bd.position = new Vector2(x, y);

        Body body = world.createBody(bd);
        body.createFixture(fd);

        return body;
    }

    bool canPut() {
        return !Input.keys['z'].down && !Input.isAltDown &&
        !Input.keys['space'].down && Input.isMouseLeftClicked &&
        contactListener.contactingBodies.isEmpty && !physicsEnabled;
    }
    
    Body addCard(double x, double y, double angle, [double zoom = 1])
    {
        PolygonShape cs = new PolygonShape();
        cs.setAsBox(CARD_WIDTH / 2 * zoom, CARD_HEIGHT / 2 * zoom);

        FixtureDef fd = new FixtureDef();
        fd.shape = cs;
        fd.density = cardDensity;
        fd.friction = cardFriction;
        fd.restitution = cardRestitution;

        BodyDef def = new BodyDef();
        def.type = getBodyType(physicsEnabled);
        def.position = new Vector2(x, y);
        def.angularDamping = 10.5;
        def.bullet = true;
        def.angle = angle;

        Body card = world.createBody(def);
        card.createFixture(fd);
        card.userData = Sprite.card();

        cards.add(card);

        return card;
    }

    int getBodyType(bool activeness)
    {
        return activeness ? BodyType.DYNAMIC : BodyType.STATIC;
    }

    void togglePhysics(bool active) {
        physicsEnabled = active;
        if (physicsEnabled) {
            bobbin.clear();
        }
        for (Body body in cards) {
            body.type = getBodyType(active);
        }
    }

    void run()
    {
        window.animationFrame.then(step);
    }

    void step(num time)
    {
        num delta = time - this.lastStepTime;

        world.step(1.0 / 60.0, 100, 100);
        update(delta);

        g.setFillColorRgb(0, 0, 0);
        g.fillRect(0, 0, WIDTH * scale, HEIGHT * scale);

        //world.drawDebugData();
        render();

        this.lastStepTime = time;
        run();
    }

    void update(num delta)
    {
        setCanvasCursor('none');
        bcard.update();
        camera.update(delta);

        if (physicsEnabled) bobbin.enterFrame(cards);

        if (isRewinding) {
            isRewinding = bobbin.previousFrame(cards);
            if (!isRewinding) bobbin = new Bobbin((){});
        }

//print(contactListener.canPut);
        if (Input.isMouseLeftClicked && contactListener.contactingBodies.isEmpty && !physicsEnabled) {
            addCard(bcard.b.position.x, bcard.b.position.y, bcard.b.angle);
        }

        if (Input.keys['z'].down && !Input.isAltDown) {
            setCanvasCursor('-webkit-zoom-in');
            if (Input.isMouseLeftClicked) zoom(true);
        }
        if (Input.isAltDown) {
            setCanvasCursor('-webkit-zoom-out');
            if (Input.isMouseLeftClicked) zoom(false);
        }

        if (contactListener.contactingBodies.isNotEmpty &&
        Input.isMouseRightClicked) {
            List<Body> cardsToDelete = new List<Body>();
            cardsToDelete.addAll(contactListener.contactingBodies);
            contactListener.contactingBodies.clear();
            for (Body contacting in cardsToDelete) {
                if (cards.contains(contacting)) {
                    world.destroyBody(contacting);
                }
            }
        }

        Input.update();
    }

    void render() {
        Body b = world.bodyList;
        while(b!=null) {
            if(b.userData!=null)
                (b.userData as Sprite).render(debugDraw, b);

            b = b.next;
        }

    }

    void restart(double d, double f, double r)
    {
        cardDensity = d;
        cardRestitution = r;
        cardFriction = f;

        for (var x in cards) {
            world.destroyBody(x);
        }
        cards = new List<Body>();

        for (int i = 0; i < 13; i++) {
            double x = i * 0.8;
            double y = -i * 0.8;
            addCard(x, y, 0);
        }

        togglePhysics(true);
    }

    void rewind()
    {
        togglePhysics(false);
        isRewinding = true;
    }

    void removeCard(Body c)
    {
        world.destroyBody(c);
        cards.remove(c);
    }

    void zoom(bool zoomIn) {
        double newZoom;

        if (zoomIn) {
            newZoom = currentZoom < 3 ? currentZoom + 0.2 : currentZoom;
        } else {
            newZoom = currentZoom >= 1.2 ? currentZoom - 0.2 : currentZoom;
        }

        camera.beginZoom(newZoom, currentZoom);
        currentZoom = newZoom;
    }
}

