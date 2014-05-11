import "dart:html";
import "dart:js";

class Scroll {
  static void setup(String visibleId, String entireId, String scrollbar, [String
      axis = 'v']) {
    JsObject scroll = new JsObject(context['dw_scrollObj'], [visibleId,
        entireId]);
    querySelector("#"+scrollbar).innerHtml = "";
    scroll.callMethod('buildScrollControls', [scrollbar, axis, 'mouseover',
        true]);
  }
}
