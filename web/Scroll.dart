import "dart:html";
import "dart:js";

class Scroll {
  JsObject scroll;

  Scroll(String visibleId, String entireId) {
    this.scroll = new JsObject(context['dw_scrollObj'], [visibleId, entireId]);
    scroll.callMethod('buildScrollControls', ['tape-scrollbar', 'h', 'mouseover', true]);
  }

  void buildScrollControls(String dragBarId, String trackId, String scrollbar, String axis) {
    //scroll.callMethod('buildScrollControls', [scrollbar, 'h']);
    //scroll.callMethod('setUpScrollbar', [dragBarId, trackId, "h", 100, 1]);
    //scroll.callMethod('setUpScrollControls', [scrollbar]);
  }
}
