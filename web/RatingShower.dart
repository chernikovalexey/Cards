import "dart:html";
import "GameEngine.dart";
import "LevelComplete.dart";

class RatingShower {
    bool active = true;

    RatingShower(GameEngine e, int rating) {
        e.isPaused = true;
        if (e.level.hasNext()) {
            (querySelector("#rating-box") as DivElement).classes.remove("hidden");
            var classes = (querySelector("#sublevel-mask") as DivElement).classes;

            for (int i = 1;i < 4;i++)
                if (classes.contains("s-" + i.toString())) classes.remove("s-" + i.toString());

            classes.add("s-" + rating.toString());
            (querySelector("#next-level") as ButtonElement).focus();
            (querySelector("#next-level") as ButtonElement).addEventListener("click", (event) {
                hide();
                e.nextLevel();
                active = false;
                e.isPaused = false;
            });

            (querySelector("#restart-level") as ButtonElement).addEventListener("click", (event) {
                hide();
                e.isPaused = false;
                e.restartLevel();
            });
        } else {
            e.level.current.getRating();
            new LevelComplete(e);
        }
    }

    void hide() {
        (querySelector("#rating-box") as DivElement).classes.add("hidden");
    }

}
