import "dart:html";
import "dart:async";
import 'dart:convert';

class Chapter {
  static List chapters;

  static void load(Function ready) {
    HttpRequest.getString("levels/chapters.json").then((String str) {
      chapters = JSON.decode(str)["chapters"];
      ready(chapters);
    });
  }
  
  // Take skipped levels into account
  // 1 2 3 7 8 9 => 6 levels finished
  static int getFinishedLevelsAmount(int chapter, int levels) {
    int finished=0;
    for(int i = 1; i <= levels; ++i) {
      if(window.localStorage.containsKey("level_"+chapter.toString() + "_"+i.toString())) {
        ++finished;
      }
    }
    return finished;
  }
}
