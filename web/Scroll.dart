import "dart:html";
import "dart:js";

class Scroll {
    JsObject scroll;
    Scroll(String scrollAreaId, String contentId) {
        scroll = new JsObject(context['dw_scrollObj'], [scrollAreaId, contentId]);
    }

    void buildScrollControls(String scrollId, String axis, String eType, bool iTrack) {
        scroll.callMethod('buildScrollControls', [scrollId, axis, eType,  iTrack]);
    }
}
