import 'dart:html';
import 'dart:js';
import 'dart:async';
import 'package:animation/animation.dart';

class Position {
  num left, top;
  Position(this.left, this.top);
}

class Tooltip {
  static int index = 0;

  static Map lastOptions; // highlighting
  static Function closeListener = (int index) {};

  static const int TOP = 1;
  static const int RIGHT = 2;
  static const int BOTTOM = 3;
  static const int LEFT = 4;
  
  static List opened = new List();

  static void show(Element rel, String code, int alignment, {num maxWidth:
      800, num xOffset: 0, num yOffset: 0, num xArrowOffset: 0, num yArrowOffset: 0})
      {
    Element body = querySelector(".game-box");
    body.appendHtml(
        '<div class="tooltip"><div class="arrow top-arrow" hidden></div><div class="arrow left-arrow" hidden></div><div class="tooltip-contents"><div class="tooltip-text">'
        + code +
        '</div><button class="got-it">Got it</button></div><div class="arrow bottom-arrow" hidden></div></div>'
        );

    Element tooltip = querySelectorAll(".tooltip").last;

    Position gameboxPos = getElementOffset(body);
    Position pos = getElementOffset(rel);

    tooltip.style.maxWidth = maxWidth.toString() + "px";

    num x = pos.left + xOffset - gameboxPos.left;
    num y = pos.top + yOffset;

    if (alignment == TOP) {
      x += rel.client.width / 2 - tooltip.client.width / 2;
      y -= tooltip.client.height;

      Element arrow = querySelector(".bottom-arrow");
      arrow.style.marginLeft = (pos.left - x + rel.client.width / 2 +
          xArrowOffset).toString() + "px";
      arrow.hidden = false;
    } else if (alignment == RIGHT) {
      x += 15 + rel.client.width;
      y += rel.client.height / 2 - tooltip.client.height / 2;

      Element arrow = querySelector(".left-arrow");
      arrow.style.marginTop = (pos.top - y + rel.client.height / 2 +
          yArrowOffset).toString() + "px";
      arrow.hidden = false;
    } else if (alignment == BOTTOM) {
      x += rel.client.width / 2 - tooltip.client.width / 2;
      y += 2 + 15 + rel.client.height;

      Element arrow = tooltip.querySelector(".top-arrow");
      arrow.style.marginLeft = (pos.left - x + rel.client.width / 2 - 15 / 2 +
          xArrowOffset - gameboxPos.left).toString() + "px";
      arrow.hidden = false;
    } else if (alignment == LEFT) {
      x -= 15 + tooltip.client.width;
      y += tooltip.client.height / 2;
    }

    opened.add(index);
    tooltip.dataset["index"] = index.toString();
    tooltip.classes.add("t-" + index.toString());

    tooltip.style.left = x.toString() + "px";
    tooltip.style.top = y.toString() + "px";

    tooltip.querySelector(".got-it").addEventListener("click", (event) {
      closeByIndex(int.parse(getParent(event.target, "tooltip").dataset["index"]
          ));
    }, false);

    ++index;
  }

  static void addCloseListener(Function listener) {
    closeListener = listener;
  }

  static void highlightByIndex(int i, Map options) {
    if (i <= index) {
      lastOptions = options;

      Element el = querySelector(".t-" + i.toString());
      el.dataset["prev-zindex"] = el.style.zIndex;
      el.style.zIndex = "999";

      for (String e in options['highlighted']) {
        el = querySelector(e);
        el.dataset["prev-zindex"] = el.style.zIndex;
        el.style.zIndex = "999";
        toggleDisabled(el, true);
      }

      for (String e in options['blurred']) {
        el = querySelector(e);
        el.classes.add("blurred");
        toggleDisabled(el, true);
      }

      querySelectorAll(".tooltip").forEach((Element el) {
        if (!el.classes.contains("t-" + i.toString())) {
          el.classes.add("blurred");
          toggleDisabled(el.querySelector(".got-it"), true);
        }
      });

      querySelector(".game-box").appendHtml('<div class="overlay"></div>');
    }
  }

  static void removeHighlighting(int i, [Function callback]) {
    if (i <= index && lastOptions != null) {
      querySelector(".overlay").remove();

      Element el = querySelector(".t-" + i.toString());

      if (el != null) {
        el.style.zIndex = el.dataset["prev-zindex"];
        el.dataset.remove("prev-zindex");
        toggleDisabled(el, false);
      }

      for (String e in lastOptions['highlighted']) {
        el = querySelector(e);
        el.style.zIndex = el.dataset["prev-zindex"];
        el.dataset.remove("prev-zindex");
        toggleDisabled(el, false);
      }

      for (String e in lastOptions['blurred']) {
        el = querySelector(e);
        el.classes.remove("blurred");
        toggleDisabled(el, false);
      }

      querySelectorAll(".tooltip").forEach((Element el) {
        el.classes.remove("blurred");
        toggleDisabled(el.querySelector(".got-it"), false);
      });
      
      new Timer(new Duration(milliseconds: 200), callback!=null?callback:(){});
    }
  }

  static void toggleDisabled(Element el, bool flag) {
    if (el is ButtonElement) {
      el.disabled = flag;
    }
  }

  static void closeByIndex(int i) {
    closeListener(i);
    opened.remove(i);
    int time = 175;
    DivElement tooltip = querySelector(".t-" + i.toString());
    animate(tooltip, properties: {
      'opacity': 0.0
    }, duration: time, easing: Easing.SINUSOIDAL_EASY_IN_OUT);
    new Timer(new Duration(milliseconds: time), () {
      tooltip.remove();
    });
  }

  static void closeAll() {
    querySelectorAll(".tooltip").forEach((Element el) {
      el.remove();
    });
  }

  static Element getParent(Element _for, String _class) {
    while (!_for.classes.contains(_class)) {
      _for = _for.parent;
    }
    return _for;
  }

  static Position getElementOffset(Element elem) {
    final docElem = document.documentElement;
    final box = elem.getBoundingClientRect();
    return new Position(box.left + window.pageXOffset - docElem.clientLeft,
        box.top + window.pageYOffset - docElem.clientTop);
  }
}
