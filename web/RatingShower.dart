import "dart:html";
import "GameEngine.dart";
import "LevelComplete.dart";

class RatingShower {
    static GameEngine e;
    static void nextLevel(event) {
        hide();
        e.nextLevel();
        e.isPaused = false;
    }

    static void restartLevel(event) {
        hide();
        e.isPaused = false;
        e.restartLevel();
    }


    static void show(GameEngine engine, int rating) {
        e = engine;

        e.isPaused = true;
        if (e.level.hasNext()) {
            (querySelector("#rating-box") as DivElement).classes.remove("hidden");
            var classes = (querySelector("#sublevel-mask") as DivElement).classes;

            for (int i = 1;i < 4;i++)
                if (classes.contains("s-" + i.toString())) classes.remove("s-" + i.toString());

            classes.add("s-" + rating.toString());
            (querySelector("#next-level") as ButtonElement).focus();
            (querySelector("#next-level") as ButtonElement).removeEventListener("click", nextLevel);

            (querySelector("#next-level") as ButtonElement).addEventListener("click", nextLevel);


            (querySelector("#restart-level") as ButtonElement).removeEventListener("click", restartLevel);
            (querySelector("#restart-level") as ButtonElement).addEventListener("click", restartLevel);
        } else {
            e.level.current.getRating();
            LevelComplete.show(e);
        }
    }

    static void hide() {
        (querySelector("#rating-box") as DivElement).classes.add("hidden");
    }

}
