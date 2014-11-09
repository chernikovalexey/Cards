import "dart:html";
import "dart:async";
import 'dart:convert';
import 'WebApi.dart';

class Chapter {
    static List chapters;

    static void load([Function ready=null]) {
        WebApi.getChapters((JsObject obj, String str) {
            chapters = JSON.decode(str)["chapters"];
            if (ready != null) {
                ready(chapters);
            }
        });
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
