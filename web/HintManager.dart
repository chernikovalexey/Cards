import "dart:html";
import "GameEngine.dart";

class HintManager {
    GameEngine engine;
    int hintsRemaining = 1;

    HintManager(this.engine) {

    }

    void onClick(Event e) {
        if(hintsRemaining>0) {
            hintsRemaining--;
        }
        querySelector("#hint-count").innerHtml = hintsRemaining.toString();
    }
}
