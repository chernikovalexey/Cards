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
import 'Traverser.dart';
import 'EnergySprite.dart';
import 'dart:async';
import 'RatingShower.dart';
import "Level.dart";
import 'SubLevel.dart';
import 'LevelSerializer.dart';
import 'ParallaxManager.dart';
import 'StateManager.dart';
import 'dart:js';
import "Color4.dart";
import "SuperCanvasDraw.dart";
import "StarManager.dart";
import 'GameWizard.dart';
import 'Tooltip.dart';
import 'PromptWindow.dart';
import 'Chapter.dart';
import 'UserManager.dart';

// Actions history item
class HItem {
    bool remove = false;
    Body card;

    HItem(this.card, this.remove);
}

class GameEngine extends State {
    static const double NSCALE = 85.0;

    static double get NWIDTH => Input.canvasWidth;

    static double get NHEIGHT => Input.canvasHeight;

    static const double NCARD_WIDTH = 45.0;
    static const double NCARD_HEIGHT = 2.5;
    static const double NENERGY_BLOCK_WIDTH = 35.0;
    static const double NENERGY_BLOCK_HEIGHT = NENERGY_BLOCK_WIDTH;
    static const double GRAVITY = -10.0;

    static double get WIDTH => NWIDTH / scale;

    static double get HEIGHT => NHEIGHT / scale;

    static double get CARD_WIDTH => NCARD_WIDTH / scale;

    static double get CARD_HEIGHT => NCARD_HEIGHT / scale;

    static double get ENERGY_BLOCK_WIDTH => NENERGY_BLOCK_WIDTH / NSCALE;

    static double get ENERGY_BLOCK_HEIGHT => NENERGY_BLOCK_HEIGHT / NSCALE;

    static double scale = NSCALE;

    num lastStepTime = 0;
    bool physicsEnabled = false;
    bool isPaused = false;
    bool ready = false;
    bool canFinishLevel = true;
    bool finishedCurrentLevel = false;

    World world;
    DefaultWorldPool pool;
    CardContactListener contactListener;
    CanvasRenderingContext2D g;
    ViewportTransform viewport;
    SuperCanvasDraw debugDraw;
    BoundedCard bcard;
    Bobbin bobbin;
    Bobbin obstaclesBobbin;
    Camera camera;
    Traverser traverser;
    Level level;

    Body from, to;

    List<HItem> history = new List<HItem>();

    List<Body> cards = new List<Body>();

    //List<Body> dynamicObstacles = new List<Body>();
    List<int> stars;
    List levels;

    bool staticBlocksSelected = false;
    bool isRewinding = false;
    bool frontRewind = false;

    Function frontRewindLevelComplete = () {
    };
    Function frontRewindLevelFailed = () {
    };
    Function onLevelEndCallback = () {
    };

    double cardDensity = 0.1, cardFriction = 0.1, cardRestitution = 0.00;
    double currentZoom = 1.0;

    GameEngine(CanvasRenderingContext2D g) {
        this.g = g;
        camera = new Camera(this);
    }

    @override
    void start([Map params]) {
        if (params != null) {
            initializeWorld();
            initializeCanvas();

            GameWizard.init();

            level = new Level(() {
                ready = true;

                this.bcard = new BoundedCard(this);
            }, params["chapter"], this, params["continue"] != null && params["continue"]);
        }
    }

    void initializeCanvas() {
        viewport = new CanvasViewportTransform(new Vector2(0.0, 0.0), new Vector2(0.0, HEIGHT));
        viewport.scale = scale;

        debugDraw = new SuperCanvasDraw(viewport, g);
    }

    void initializeWorld() {
        pool = new DefaultWorldPool();

        this.contactListener = new CardContactListener(this);
        this.world = new World(new Vector2(0.0, GRAVITY), true, pool);

        world.contactListener = contactListener;

        this.traverser = new Traverser(this);

        this.bobbin = new Bobbin(() {
            traverser.reset();

            if (from.contactList != null) {
                traverser.traverseEdges(from.contactList);
            }

            if (!traverser.hasPath) {
                if (!cards.isEmpty) {
                    GameWizard.showRewind();
                }

                for (Body card in cards) {
                    if (traverser.checkEnergyConnection(card)) {
                        traverser.traverseEdges(card.contactList);
                    }
                }
            }
            /* else if (level.chapter == 1 && level.current.index == 1) {
                GameWizard.showGoal();
            }*/

            if (!traverser.hasPath && frontRewind) {
                frontRewindLevelFailed();
            }
        });

        this.obstaclesBobbin = new Bobbin(() {
        });
    }

    void setCanvasCursor(String _class) {
        canvas.classes.clear();
        canvas.classes.add(_class + "-cursor");
    }

    FixtureDef createHelperFixture(double w, double h) {
        FixtureDef fd = new FixtureDef();
        fd.isSensor = true;
        PolygonShape s = new PolygonShape();
        s.setAsBox(w / 2, h / 2);
        fd.shape = s;
        fd.userData = false;

        return fd;
    }

    void adjustFixture(FixtureDef fd, bool _dynamic) {
        if (_dynamic) {
            fd.density = cardDensity;
            fd.friction = cardFriction;
            fd.restitution = cardRestitution;
        } else {
            fd.friction = 0.7;
        }
    }

    void adjustBody(BodyDef bd, bool _dynamic) {
        if (_dynamic) {
            bd.angularDamping = 10.5;
        }
    }

    Body createPolygonShape(double x, double y, double width, double height, [bool _dynamic = false]) {
        PolygonShape sd = new PolygonShape();
        sd.setAsBox(width / 2, height / 2);

        FixtureDef fd = new FixtureDef();
        fd.shape = sd;
        adjustFixture(fd, _dynamic);

        BodyDef bd = new BodyDef();
        bd.position = new Vector2(x + width / 2, y + height / 2);
        adjustBody(bd, _dynamic);

        Body body = world.createBody(bd);
        body.createFixture(fd);
        body.createFixture(createHelperFixture(width, height));

        return body;
    }

    Body createMultiShape(List<Vector2> points, [bool _dynamic = false]) {
        PolygonShape sd = new PolygonShape();
        sd.setFrom(points, points.length);

        FixtureDef fd = new FixtureDef();
        fd.shape = sd;
        adjustFixture(fd, _dynamic);

        BodyDef bd = new BodyDef();
        adjustBody(bd, _dynamic);

        Body body = world.createBody(bd);
        body.createFixture(fd);

        return body;
    }

    bool canPut([bool ignorePhysics = false]) {
        return !Input.keys['z'].down && !Input.isAltDown && !Input.keys['space'].down && (Input.isMouseLeftClicked || Input.keys['enter'].clicked) && contactListener.contactingBodies.isEmpty && (ignorePhysics || !physicsEnabled);
    }

    Body addCard(double x, double y, double angle, [bool isStatic = false, SubLevel sub = null, Color4 col = null, bool isHint = false]) {
        PolygonShape cs = new PolygonShape();
        cs.setAsBox(GameEngine.CARD_WIDTH / 2 * currentZoom, GameEngine.CARD_HEIGHT / 2 * currentZoom);

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
        card.createFixture(createHelperFixture(CARD_WIDTH, CARD_HEIGHT));

        EnergySprite sprite = Sprite.card(world);
        sprite.isStatic = isStatic;
        sprite.energySupport = (!isStatic || sub != null);
        sprite.isHint = isHint;

        if (col != null) {
            sprite.color = col;
        } else {
            if (isStatic) {
                sprite.color = new Color4.fromRGB(217, 214, 179);
            }
        }

        card.userData = sprite;

        if (sub == null) {
            sub = level.current;
            cards.add(card);
        } else {
            sub.cards.add(card);
        }

        if (!isHint) {
            if (isStatic) {
                --sub.staticBlocksRemaining;

                if (sub.staticBlocksRemaining == 0) {
                    this.staticBlocksSelected = false;
                }
            } else {
                --sub.dynamicBlocksRemaining;
            }

            updateBlockButtons(this);
        }

        return card;
    }

    int getBodyType(bool activeness, [bool isStatic = false, bool isHint = false]) {
        return activeness && !isStatic && !isHint ? BodyType.DYNAMIC : BodyType.STATIC;
    }

    void togglePhysics(bool active) {
        physicsEnabled = active;

        if (physicsEnabled) {
            ++level.current.attemptsUsed;
            UserManager.decrement("allAttempts");

            bobbin.erase();
            bobbin.enterFrame(cards);
        } else {
            (to.userData as Sprite).deactivate();
        }

        for (Body body in cards) {
            EnergySprite sprite = body.userData as EnergySprite;
            body.type = getBodyType(active, sprite.isStatic, sprite.isHint);
            if (!physicsEnabled) sprite.deactivate();
        }

        // Toggle dynamic obstacles
        if (physicsEnabled) {
            obstaclesBobbin.erase();
            obstaclesBobbin.enterFrame(level.current.obstacles);
        }

        for (Body obstacle in level.current.obstacles) {
            bool isStatic = (obstacle.userData as Sprite).isStatic;
            if (!isStatic) {
                obstacle.type = getBodyType(active, isStatic, false);
            }
        }
    }

    void toggleBoundedCard(bool visible) {
        (bcard.b.userData as Sprite).isHidden = !visible;
    }

    @override
    void update(num delta) {
        if (!ready || isPaused) {
            return;
        }

        if (Input.keys['esc'].clicked && !finishedCurrentLevel) {
            PromptWindow.close();
            Tooltip.closeAll();

            // Close controls viewer first
            if (querySelector("#wizard-controls").classes.contains("hidden")) {
                RatingShower.pause(this);
            } else {
                querySelector(".wizard-try").click();
            }

            saveCurrentProgress();
        }
        RatingShower.wasJustPaused = false;

        setCanvasCursor('none');

        camera.update(delta);

        if (physicsEnabled) {
            bobbin.enterFrame(cards);
            if (level != null && level.current != null) obstaclesBobbin.enterFrame(level.current.obstacles);
        }

        if (isRewinding) {
            if (level != null && level.current != null) {
                bool cardsRewind = bobbin.previousFrame(cards);
                bool obstaclesRewind = obstaclesBobbin.previousFrame(level.current.obstacles);
                isRewinding = cardsRewind || obstaclesRewind;
            }

            if (!isRewinding) {
                bobbin.erase();
                obstaclesBobbin.erase();
                if (bobbin.rewindComplete != null) bobbin.rewindComplete();
            }
        }

        if (level != null && level.current != null) {
            for (Body obstacle in level.current.obstacles) {
                obstacle.applyForce(new Vector2(0.0, -0.0005), obstacle.worldCenter);
            }
        }

        world.step(1.0 / 60, 10, 10);
        if (bcard != null) {
            bcard.update();
        }

        bool cp = canPut();
        if (level.current != null && ((staticBlocksSelected && level.current.staticBlocksRemaining > 0) || (!staticBlocksSelected && level.current.dynamicBlocksRemaining > 0))) {
            if (cp) {
                Body put = addCard(bcard.b.position.x, bcard.b.position.y, bcard.b.angle, staticBlocksSelected);
                addHistoryState(put, false);
            } else if (canPut(true)) {
                blinkPhysicsButton();
            }
        } else if (cp && staticBlocksSelected && level.current.staticBlocksRemaining == 0) {
            blink(".static");
        } else if (cp && !staticBlocksSelected && level.current.dynamicBlocksRemaining == 0) {
            blink(".dynamic");
        }

        if (canPut() && level.current.dynamicBlocksRemaining == 0 && level.current.staticBlocksRemaining == 0) {
            GameWizard.showRunout();
        }

        //
        // Button clicks

        if ((Input.keys['shift'].down && Input.keys['z'].clicked) || (Input.keys['z'].down && Input.keys['shift'].clicked)) {
            toggleBoundedCard(false);
            zoom(true);
        } else if ((Input.keys['z'].down && Input.isAltClicked) || (Input.isAltDown && Input.keys['z'].clicked)) {
            toggleBoundedCard(false);
            zoom(false);
        }

        if (Input.keys['1'].clicked) {
            staticBlocksSelected = false;
            updateBlockButtons(this);
        }
        if (Input.keys['2'].clicked && level.current.staticBlocksRemaining > 0) {
            staticBlocksSelected = true;
            updateBlockButtons(this);
        }
        if ((Input.keys['ctrl'].down || Input.isCmdDown) && Input.keys['shift'].clicked || (Input.keys['ctrl'].clicked || Input.isCmdClicked) && Input.keys['shift'].down) {
            querySelector('#toggle-physics').click();
        }

        if (contactListener.contactingBodies.isNotEmpty && (Input.isMouseRightClicked || Input.keys['delete'].clicked) && !isRewinding) {
            List<Body> cardsToRemove = new List<Body>();
            cardsToRemove.addAll(contactListener.contactingBodies);
            contactListener.contactingBodies.clear();
            for (Body contacting in cardsToRemove) {
                if (cards.contains(contacting)) {
                    removeCard(contacting);
                    addHistoryState(contacting, true);
                }
            }
        } else if (!physicsEnabled && Input.keys['ctrl'].down && Input.keys['z'].clicked && history.length > 0) {
            HItem last = history.removeLast();
            bool s = (last.card.userData as EnergySprite).isStatic;

            if (last.remove) {
                addCard(last.card.position.x, last.card.position.y, last.card.angle, s);
            } else {
                removeCard(last.card);
            }
        }

        for (Body c in cards) {
            (c.userData as EnergySprite).update(this);
        }

        finishedCurrentLevel = false;
        if (to != null) {
            EnergySprite sprite = to.userData as EnergySprite;
            if (physicsEnabled) {
                sprite.update(this);

                if (sprite.isFull() && canFinishLevel && level.current != null) {
                    onLevelEndCallback();
                    finishedCurrentLevel = true;

                    level.current.completed = true;
                    level.current.getRating();
                    saveCurrentProgress();

                    if (!frontRewind) {
                        StarManager.saveFrom(level.chapter, level.subLevels);
                        RatingShower.show(this, level.current.rating);
                    }

                    if (level.chapter == 1 && level.current.index == 1) {
                        GameWizard.finish();
                    }

                    if (frontRewind) {
                        frontRewindLevelComplete();
                    }
                }
            } else {
                sprite.deactivate();
            }
        }

        Input.update();
    }

    void addOnLevelEndCallback(Function callback) {
        this.onLevelEndCallback = callback;
    }

    void removeOnLevelEndCallback() {
        this.onLevelEndCallback = () {
        };
    }

    int countCards(bool countStatic) {
        int n = 0;
        for (Body c in cards) {
            n += ((c.userData as EnergySprite).isStatic == countStatic) ? 1 : 0;
        }
        return n;
    }

    // saves the state of the current level

    void saveCurrentProgress() {
        if (level != null && level.current != null) {
            String id = 'level_' + level.chapter.toString() + '_' + level.current.index.toString();

            // No sense to save empty states, indeed
            if (ready && (window.localStorage.containsKey(id) || !cards.isEmpty)) {
                window.localStorage[id] = LevelSerializer.toJSON(cards, bobbin.list, level.current.obstacles, obstaclesBobbin.list, physicsEnabled, level.current.completed);
            }
        }
    }

    void previousLevel() {
        level.previous();
    }

    void restartLevel() {
        applyPhysicsLabelToButton();
        (to.userData as EnergySprite).energy = 0.0;
    }

    void nextLevel() {
        if (level.hasNext()) {
            history.clear();
            if (level.current.finish()) {
                level.next();
            }
        }
    }

    void addHistoryState(Body body, bool remove) {
        int max = level.current.maxDynamicBlocks + level.current.maxStaticBlocks;
        int current = 0;

        for (HItem item in history)
            if (item.remove == remove) ++current;

        if (current < max) {
            history.add(new HItem(body, remove));
            history.add(new HItem(body, remove));
        }
    }

    @override
    void render() {
        if (ready) {
            Body b = world.bodyList;
            while (b != null) {
                if (b.userData != null) (b.userData as Sprite).render(debugDraw, b);
                b = b.next;
            }
        }
    }

    void restart(double d, double f, double r) {
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
            addCard(x, y, 0.0);
        }

        togglePhysics(true);
    }

    void rewind([List list]) {
        if (list != null) {
            bobbin.list = list;
        }
        togglePhysics(false);
        isRewinding = true;
    }

    void removeCard(Body c) {
        // Add-immediate-remove bug fix
        if (history.length > 0) {
            List<HItem> _history = new List<HItem>();
            _history.addAll(history);
            for (HItem item in _history) {
                if (!item.remove && item.card == c) {
                    history.remove(item);
                }
            }
        }

        world.destroyBody(c);
        cards.remove(c);

        EnergySprite sprite = c.userData as EnergySprite;
        if (!sprite.isHint) {
            if (sprite.isStatic && level.current.staticBlocksRemaining + 1 <= level.current.maxStaticBlocks) {
                ++level.current.staticBlocksRemaining;
            } else if (level.current.dynamicBlocksRemaining + 1 <= level.current.maxDynamicBlocks) {
                ++level.current.dynamicBlocksRemaining;
            }
            updateBlockButtons(this);
        }
    }

    void zoom(bool zoomIn) {
        double zoomDelta = 0.2;
        double newZoom;

        if (zoomIn) {
            newZoom = currentZoom <= 3 - zoomDelta ? currentZoom + zoomDelta : currentZoom;
        } else {
            newZoom = currentZoom >= 1.0 + zoomDelta ? currentZoom - zoomDelta : currentZoom;
        }

        if (newZoom != currentZoom) {
            camera.beginZoom(newZoom, currentZoom);
            camera.updateZoom();

            camera.mTargetX = from.position.x + (to.position.x - from.position.x) / 2 - WIDTH / 2;
            camera.mTargetY = from.position.y + (to.position.y - from.position.y) / 2 - HEIGHT / 2;

            camera.ignoreAutoCheck = true;
            camera.checkTarget();
            camera.updateEngine();

            currentZoom = newZoom;

            camera.zoomEnd = () {
                camera.ignoreAutoCheck = false;
            };
        }
    }

    void clear() {
        window.localStorage.remove("level_" + level.chapter.toString() + "_" + (level.current.index + 1).toString());
        applyPhysicsLabelToButton();
        bobbin.erase();
        obstaclesBobbin.erase();
        List<Body> _cards = new List<Body>();
        _cards.addAll(cards);
        for (Body b in _cards) {
            removeCard(b);
        }
    }
}