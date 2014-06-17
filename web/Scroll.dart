import "dart:html";
import "dart:js";

class Scroll {
  static JsObject setup(String visibleId, String entireId, String
      scrollbar, [String axis = 'v']) {
    JsObject scroll = new JsObject(context['dw_scrollObj'], [visibleId,
        entireId]);
    querySelector("#" + scrollbar).innerHtml = "";
    scroll.callMethod('buildScrollControls', [scrollbar, axis, 'mouseover',
        true]);
    return scroll;
  }
  
  static void scrollTo(String visibleId, String scrollToId) {
    context['dw_scrollObj'].callMethod('scrollToId', [visibleId, scrollToId, '', 550]);
  }
}
