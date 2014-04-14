import "dart:html";
import "GameEngine.dart";

class RatingShower {
    bool active = true;

    RatingShower(GameEngine e, int rating) {
        (querySelector("#rating-box") as DivElement).classes.remove("hidden");
        (querySelector("#sublevel-mask") as DivElement).classes.add("s-"+rating.toString());
        (querySelector("#next-level") as ButtonElement).focus();
        (querySelector("#next-level") as ButtonElement).addEventListener("click",(event){
            hide();
            e.nextLevel();
            active = false;
        });

        (querySelector("#restart-level") as ButtonElement).addEventListener("click",(event){
            hide();
            e.restartLevel();
        });
    }

    void hide() {
        (querySelector("#rating-box") as DivElement).classes.add("hidden");
    }

}
