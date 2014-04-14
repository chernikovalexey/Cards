import "dart:html";
import "GameEngine.dart";

class RatingShower {
    bool active = true;

    RatingShower(GameEngine e, int rating) {
        (querySelector(".light-box") as DivElement).classes.remove("hidden");
        (querySelector(".rating-mask") as DivElement).classes.add("s-"+rating.toString());
        (querySelector("#next-level") as ButtonElement).focus();
        (querySelector("#next-level") as ButtonElement).addEventListener("click",(event){
            (querySelector(".light-box") as DivElement).classes.add("hidden");
            active = false;
        });

        (querySelector("#restart-level") as ButtonElement).addEventListener("click",(event){
            e.restartLevel();
        });
    }
}
