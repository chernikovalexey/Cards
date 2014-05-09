import "dart:html";
import "GameEngine.dart";
import "LevelComplete.dart";
import "SubLevel.dart";
import "Level.dart";
import "Scroll.dart";

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

    static String tapeItem(Map l, int index, int current) {
        DivElement el = (querySelector(".tape-item-template") as DivElement);
//el.querySelector(".tape-rating").innerHtml = l.rating.toString();
        el.querySelector(".tape-name").innerHtml = l["name"];
        DivElement tr = el.querySelector(".tape-rating") as DivElement;
        DivElement ti = el.querySelector(".tape-item") as DivElement;
        ti.dataset['level'] = (index + 1).toString();

        if (index < e.level.subLevels.length) {
            tr.classes.add("tr-" + e.level.subLevels[index].rating.toString());
        } else {
            tr.classes.add("tr-0");
            ti.classes.add("locked");
        }

        if (index == current)
            ti.classes.add("tape-current-item");

        String result = el.innerHtml;

        if (ti.classes.contains("locked"))
            ti.classes.remove("locked");

        if (index == current)
            ti.classes.remove("tape-current-item");

        tr.classes.clear();
        tr.classes.add("tape-rating");

        return result;
    }

    static void show(GameEngine engine, int rating) {
        e = engine;

        e.isPaused = true;
        (querySelector("#rating-box") as DivElement).classes.remove("hidden");

        var classes = (querySelector(".level-rating") as DivElement).classes;

        for (int i = 1;i < 4;i++)
            if (classes.contains("s-" + i.toString())) classes.remove("s-" + i.toString());

        (querySelector(".s-level-name") as DivElement).innerHtml = e.level.current.name;
        (querySelector(".chapter-level") as DivElement).innerHtml = e.level.current.index.toString() + " of " + e.level.levels.length.toString();

        classes.add("s-" + rating.toString());
        (querySelector("#next-level") as ButtonElement).focus();
        (querySelector("#next-level") as ButtonElement).removeEventListener("click", nextLevel);

        (querySelector("#next-level") as ButtonElement).addEventListener("click", nextLevel);

        (querySelector("#restart-level") as ButtonElement).removeEventListener("click", restartLevel);
        (querySelector("#restart-level") as ButtonElement).addEventListener("click", restartLevel);

        (querySelector(".tape") as DivElement).innerHtml = "";
        String s = "";
        for (int i = 0;i < e.level.levels.length;i++) {
            s += tapeItem(e.level.levels[i], i, e.level.currentSubLevel - 1);
        }

        final NodeValidatorBuilder _htmlValidator = new NodeValidatorBuilder.common()
        ..allowElement('div', attributes: ['data-target', 'data-level']);


        (querySelector(".tape") as DivElement).setInnerHtml(s, validator: _htmlValidator);

        for (DivElement e in querySelectorAll(".tape-item")) {
            e.removeEventListener("click", onTypeItemClick);
            e.addEventListener("click", onTypeItemClick);
        }


        //todo: Scroll
        /*Scroll ss = new Scroll('t-box', 't');
        ss.buildScrollControls('scrollbar', 'h', 'mouseover', true);*/

        if(!e.level.hasNext()) {
            chapterComplete();
        }
    }

    static void pause(GameEngine e) {
        show(e, 0);
    }

    static void chapterComplete() {
        querySelector(".rating-wrap").classes.add("hidden");
        querySelector(".chapter-rating-wrap").classes.remove("hidden");
        int totalStars = 0;
        for(SubLevel l in e.level.subLevels) {
            totalStars+=l.rating;
        }
        querySelector(".chapter-raring").innerHtml = totalStars.toString();
    }


    static void onTypeItemClick(Event evt) {
        hide();
        e.isPaused = false;
        Level.navigateToLevel(int.parse((evt.currentTarget as DivElement).dataset['level']), e);
    }


    static void hide() {
        (querySelector("#rating-box") as DivElement).classes.add("hidden");
    }

}
