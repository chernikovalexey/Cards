import "dart:js";

class Analytics {
  JsObject object;
  Map timers;

  Analytics() {
    object = new JsObject(context['Analytics']);
    timers = new Map();
  }

  void startSession() {
    object.callMethod('startSession');
  }

  void applyPhysics(int chapter, int level) {
    object.callMethod('applyPhysics', [chapter, level]);
  }

  void rewindPhysics(int chapter, int level) {
    object.callMethod('rewindPhysics', [chapter, level]);
  }

  void levelStart(chapter, level) {
    DateTime time = new DateTime.now();
    timers[chapter.toString() + "." + level.toString()] =
        time.millisecondsSinceEpoch / 1000;
  }

  void levelComplete(chapter, level, nStatic, nDynamic, stars) {
    DateTime t = new DateTime.now();
    num time = 0;
    if (timers[chapter.toString() + "." + level.toString()] != null) {
      num s = timers[chapter.toString() + "." + level.toString()];
      time = (t.millisecondsSinceEpoch / 1000 - s).round();
    }
    object.callMethod('levelComplete', [chapter, level, nStatic, nDynamic,
        stars, time]);
  }
}
