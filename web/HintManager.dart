import "dart:html";
import "GameEngine.dart";
import 'dart:js';
import 'PromptWindow.dart';
import 'package:box2d/box2d_browser.dart';
import 'package:sprintf/sprintf.dart';
import 'EnergySprite.dart';
import 'Color4.dart';
import 'dart:async';
import 'package:animation/animation.dart';
import 'UserManager.dart';
import 'WebApi.dart';
import 'Tooltip.dart';

class HintManager {
    GameEngine engine;
    bool purchasesWindowLoaded = false;

    HintManager(this.engine);

    void onClick(Event e) {
        int balance = UserManager.getAsInt("balance");

        Tooltip.closeAll();

        if (balance > 0) {
            PromptWindow.show(context['locale']['use_hint_question'], context['locale']['surely_want'], sprintf(context['locale']['hints_left'], [balance.toString(), context['Features'].callMethod('getNounPlural', [balance, context['locale']['hint_form1'], context['locale']['hint_form2'], context['locale']['hint_form3']])]), context['locale']['get_more'], getMoreHints, (bool positive) {
                if (positive) {
                    context['Api'].callMethod('call', ['getHint', new JsObject.jsify({
                        'chapter': engine.level.chapter, 'level': engine.level.currentSubLevel
                    }), (Map hints) {
                        UserManager.set("balance", hints['user']['balance']);
                        querySelector("#hints-amount").innerHtml = hints['user']['balance'].toString();

                        for (Map card in hints['hint']) {
                            addHintCard(card['x'].toDouble(), card['y'].toDouble(), card['angle'].toDouble(), card['energy'].toDouble(), card['static']);
                        }

                        // 6.5 sec enough?
                        new Timer(new Duration(milliseconds: 6500), () {
                            clearHintCards();
                        });

                        PromptWindow.close();
                    }]);
                } else {
                    PromptWindow.close();
                }
            });
        } else {
            PromptWindow.showSimple(context['locale']['hints_lack'], context['locale']['spent_hints'], context['locale']['get_hints'], getMoreHints);
        }
    }

    void orderSuccessCallback() {
        print("order success");
        WebApi.getUser(() {
            print("get user success");
            querySelector("#hints-amount").innerHtml = querySelector("#hints-balance").innerHtml = UserManager.getAsString("balance");
            querySelector("#attempts-balance").innerHtml = querySelector("#attempts-remaining").innerHtml = UserManager.getAsInt('boughtAttempts') == -1 ? "∞" : UserManager.getAsString("allAttempts");
            WebApi.onOrderSuccess(orderSuccessCallback);
        });
    }

    void getMoreHints([Event event]) {
        if (!purchasesWindowLoaded) {
            WebApi.loadPurchasesWindow();
            purchasesWindowLoaded = true;
        }
        PromptWindow.close();
        Tooltip.closeAll();

        WebApi.onOrderSuccess(orderSuccessCallback);

        querySelector('#purchases').classes.remove("hidden");
        animate(querySelector('#purchases'), properties: {
            'top': 0, 'opacity': 1.0
        }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);

        querySelector("#hints-balance").innerHtml = UserManager.getAsString("balance");
        querySelector("#attempts-balance").innerHtml = UserManager.getAsInt('boughtAttempts') == -1 ? "∞" : UserManager.getAsString("allAttempts");

        querySelector(".close-purchases").addEventListener("click", (event) {
            //querySelector('.game-box').classes.remove('blurred');
            animate(querySelector('#purchases'), properties: {
                'top': 800, 'opacity': 0.0
            }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);
        }, false);
    }

    void addHintCard(double x, double y, double angle, double energy, bool _static) {
        Color4 col = new Color4.fromRGBA(235, 175, 130, 0.25);
        if (_static) {
            col = new Color4.fromRGBA(235, 235, 215, 0.25);
        }
        Body b = engine.addCard(x, y, angle, _static, null, col, true);
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