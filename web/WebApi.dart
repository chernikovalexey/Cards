import "dart:js";
import "dart:core";

class WebApi {
    WebApi() {
      
    }

    static DateTime startTime;
    static int chapter, level, attempts;

    static void levelStart(int _chapter, int _level) {
      startTime = new DateTime.now();
      chapter = _chapter;
      level = _level;
      attempts = 0;
    }
    
    static void addAttempt() {
      attempts++;
    }
    
    static void finishLevel(int result, int dynamic, int nStatic) {
      num time = (new DateTime.now().difference(startTime)).inSeconds;
      (context['Features'] as JsObject).callMethod('onLevelFinish', [chapter, level, result, dynamic, nStatic, attempts, time]);
    }
}
