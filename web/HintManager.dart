import "dart:html";
import "GameEngine.dart";
import 'dart:js';
import 'PromptWindow.dart';
import 'package:box2d/box2d_browser.dart';
import 'EnergySprite.dart';
import 'Color4.dart';

class HintManager {
    GameEngine engine;
    int hintsRemaining = 1;

    HintManager(this.engine) {
    }

    void onClick(Event e) {
        /*if(hintsRemaining>0) {
            hintsRemaining--;
        }
        querySelector("#hint-count").innerHtml = hintsRemaining.toString();*/

        PromptWindow.show("Use hint?", "You surely want?", (bool positive) {
            if (positive) {
                context['Api'].callMethod('call', ['getHint', new JsObject.jsify({
                    'chapter': engine.level.chapter, 'level': engine.level.currentSubLevel
                }), (Map hints) {
                    for (Map card in hints['hint']) {
                        Body b = engine.addCard(card['x'].toDouble(), card['y'].toDouble(), card['angle'].toDouble(), card['static'], null, new Color4.fromRGBA(255, 255, 255, 0.25));
                        b.type = BodyType.STATIC;
                        (b.userData as EnergySprite).energy = card['energy'].toDouble();
                    }

                    PromptWindow.close();
                }]);
            }
        });
    }
}