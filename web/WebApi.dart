import "dart:js";
import "dart:core";

class WebApi {
    WebApi() {
    }

    static DateTime startTime;
    static int chapter, level;

    static void levelStart(int _chapter, int _level) {
        startTime = new DateTime.now();
        chapter = _chapter;
        level = _level;
    }

    static void finishLevel(int result, int _dynamic, int nStatic, int attempts) {
        num time = (new DateTime.now().difference(startTime)).inSeconds;
        (context['Features'] as JsObject).callMethod('onLevelFinish', [chapter, level, result, _dynamic, nStatic, attempts, time]);
    }

    static void attemptsRanOut(int delta) {
        context['Features'].callMethod('addAttempts', [delta]);
    }

    static void showFriends() {
        (context['Features'] as JsObject).callMethod('showFriendsBar');
    }
}
