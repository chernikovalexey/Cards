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

    static void updateAttemptsAmount(int delta) {
        context['Api'].callMethod('call', ['addAttempts', new JsObject.jsify({
            'attemptsUsed': delta
        })]);
    }

    static void showFriends() {
        (context['Features'] as JsObject).callMethod('showFriendsBar');
    }

    static void loadPurchasesWindow() {
        (context['Features'] as JsObject).callMethod('loadPurchasesWindow');
    }
}
