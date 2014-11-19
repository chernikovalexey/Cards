import "dart:html";
import "dart:async";
import 'dart:convert';
import 'WebApi.dart';

class Chapter {
    static bool loading = false;
    static bool loaded = false;
    static List chapters;
    static List<Function> callbacks = new List<Function>();

    static void load([Function ready = null]) {
        if (!loaded && !loading) {
            loading = true;

            if (ready != null) {
                callbacks.add(ready);
            }

            WebApi.getChapters((JsObject obj, String str) {
                chapters = JSON.decode(str)["chapters"];
                fireCallbacks();
                loaded = true;
                loading = false;
            });
        } else if (loaded && ready != null) {
            ready(chapters);
        } else if (!loaded && loading && ready != null) {
            callbacks.add(ready);
        }
    }

    static void fireCallbacks() {
        for (Function f in callbacks) {
            f(chapters);
        }
    }

    // Take skipped levels into account
    // 1 2 3 7 8 9 => 6 levels finished

    static int getFinishedLevelsAmount(int chapter, int levels) {
        int finished = 0;
        for (int i = 1; i <= levels; ++i) {
            if (window.localStorage.containsKey("level_" + chapter.toString() + "_" + i.toString())) {
                ++finished;
            }
        }
        return finished;
    }
}
