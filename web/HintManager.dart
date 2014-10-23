import "dart:html";
import "GameEngine.dart";
import 'dart:js';
import 'PromptWindow.dart';
import 'package:box2d/box2d_browser.dart';
import 'EnergySprite.dart';
import 'Color4.dart';
import 'dart:async';

class HintManager {
    GameEngine engine;
    int hintsRemaining = 1;

    HintManager(this.engine);

    void onClick(Event e) {
        if (hintsRemaining > 0) {


            PromptWindow.show("Use hint?", "You surely want?", (bool positive) {
                if (positive) {
                    context['Api'].callMethod('call', ['getHint', new JsObject.jsify({
                        'chapter': engine.level.chapter, 'level': engine.level.currentSubLevel
                    }), (Map hints) {
                        hintsRemaining = hints['user']['balance'].toInt();
                        querySelector("#hints-amount").innerHtml = hintsRemaining.toString();

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
        }
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