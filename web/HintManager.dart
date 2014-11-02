import "dart:html";
import "GameEngine.dart";
import 'dart:js';
import 'PromptWindow.dart';
import 'package:box2d/box2d_browser.dart';
import 'EnergySprite.dart';
import 'Color4.dart';
import 'dart:async';
import 'package:animation/animation.dart';
import 'UserManager.dart';
import 'WebApi.dart';

class HintManager {
    GameEngine engine;
    bool purchasesWindowLoaded = false;

    HintManager(this.engine);

    void onClick(Event e) {
        int balance = UserManager.getAsInt("balance");

        if (balance > 0) {
            PromptWindow.show("Use hint?", "You surely want?", "Only <b>" + balance.toString() + "</b> left", "get more", getMoreHints, (bool positive) {
                if (positive) {
                    context['Api'].callMethod('call', ['getHint', new JsObject.jsify({
                        'chapter': engine.level.chapter, 'level': engine.level.currentSubLevel
                    }), (Map hints) {
                        UserManager.set("balance", hints['user']['balance']);
                        querySelector("#hints-amount").innerHtml = hints['user']['balance'].toString();

                        for (Map card in hints['hint']) {
                            addHintCard(card['x'].toDouble(), card['y'].toDouble(), card['angle'].toDouble(), card['energy'].toDouble(), card['static']);
                        }

                        new Timer(new Duration(seconds: 5), () {
                            clearHintCards();
                        });

                        PromptWindow.close();
                    }]);
                } else {
                    PromptWindow.close();
                }
            });
        } else {
            PromptWindow.showSimple("Lack of hints", "You've unfortunately spent all available hints.", "Get hints", getMoreHints);
        }
    }

    void getMoreHints([Event event]) {

        if(!purchasesWindowLoaded) {
            WebApi.loadPurchasesWindow();
            purchasesWindowLoaded = true;
        }
        PromptWindow.close();

        querySelector('#purchases').classes.remove("hidden");
        animate(querySelector('#purchases'), properties: {
            'top': 0, 'opacity': 1.0
        }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);

        querySelector("#hints-balance").innerHtml = UserManager.getAsString("balance");
        querySelector("#attempts-balance").innerHtml = UserManager.getAsString("allAttempts");

        querySelector(".close-purchases").addEventListener("click", (event) {
            //querySelector('.game-box').classes.remove('blurred');
            animate(querySelector('#purchases'), properties: {
                'top': 800, 'opacity': 0.0
            }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);
        }, false);
    }

    void addHintCard(double x, double y, double angle, double energy, bool static) {
        Body b = engine.addCard(x, y, angle, static, null, new Color4.fromRGBA(255, 255, 255, 0.25), true);
        b.type = BodyType.STATIC;
        (b.userData as EnergySprite).energy = energy;
    }

    void clearHintCards() {
        List<Body> _cards = new List<Body>();
        _cards.addAll(engine.cards);
        for (Body card in _cards) {
            EnergySprite sprite = card.userData as EnergySprite;
            if (sprite.isHint) {
                engine.removeCard(card);
            }
        }
    }
}