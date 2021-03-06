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

    static Map lastOptions;

    // highlighting
    static Function closeListener = (int index) {
    };

    static const int TOP = 1;
    static const int RIGHT = 2;
    static const int BOTTOM = 3;
    static const int LEFT = 4;

    static List<int> opened = new List<int>();

    static int showSimple(String text, int x, int y, [Function callback = null, String title=""]) {
        Element body = querySelector("body");

        if (title != "") {
            title = '<div class="simple-tooltip-title">' + title + '</div>';
        }

        body.appendHtml('<div class="tt simple-tooltip"><div class="simple-tooltip-white-layout">' + title + '<div class="simple-tooltip-text">' + text + '</div><button class="got-it">OK</button></div></div>');

        Element tooltip = querySelectorAll(".simple-tooltip").last;
        tooltip.style.left = x.toString() + "px";
        tooltip.style.top = y.toString() + "px";

        opened.add(index);

        tooltip.classes.add("t-" + index.toString());
        tooltip.dataset["index"] = index.toString();

        tooltip.querySelector(".simple-tooltip .got-it").addEventListener("click", (event) {
            closeByIndex(int.parse(getParent(event.target, "simple-tooltip").dataset["index"]));
            if (callback != null) {
                callback();
            }
        }, false);

        int _index = index;
        ++index;
        return _index;
    }

    static int show(Element rel, String code, int alignment, {num maxWidth: 800, num xOffset: 0, num yOffset: 0, num xArrowOffset: 0, num yArrowOffset: 0, int closeDelay: 0, Function callback: null}) {
        Element body = querySelector(".game-box");
        body.appendHtml('<div class="tt tooltip"><div class="arrow top-arrow" hidden></div><div class="arrow left-arrow" hidden></div><div class="tooltip-contents"><div class="tooltip-text">' + code + '</div><button class="got-it">OK</button></div><div class="arrow bottom-arrow" hidden></div></div>');

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
            arrow.style.marginLeft = (pos.left - x + rel.client.width / 2 + xArrowOffset).toString() + "px";
            arrow.hidden = false;
        } else if (alignment == RIGHT) {
            x += 15 + rel.client.width;
            y += rel.client.height / 2 - tooltip.client.height / 2;

            Element arrow = querySelector(".left-arrow");
            arrow.style.marginTop = (pos.top - y + rel.client.height / 2 + yArrowOffset).toString() + "px";
            arrow.hidden = false;
        } else if (alignment == BOTTOM) {
            x += rel.client.width / 2 - tooltip.client.width / 2;
            y += 2 + 15 + rel.client.height;

            Element arrow = tooltip.querySelector(".top-arrow");
            arrow.style.marginLeft = (pos.left - x + rel.client.width / 2 - 15 / 2 + xArrowOffset - gameboxPos.left).toString() + "px";
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

        tooltip.querySelector(".t-" + index.toString() + " .got-it").addEventListener("click", (event) {
            closeByIndex(int.parse(getParent(event.target, "tooltip").dataset["index"]));
            if (callback != null) {
                callback();
            }
        }, false);

        addChildClasses();

        var stream = querySelector("body").onClick.listen((event) {
            Element el = event.currentTarget as Element;
            if (!el.classes.contains("tt-child")) {
                new Timer(new Duration(milliseconds: closeDelay), () {
                    Tooltip.closeAll();
                    if (callback != null) {
                        callback();
                    }
                });
            }
        });

        querySelector("body").onClick.listen((event) {
            stream.cancel();
        });

        int _index = index;
        ++index;

        return _index;
    }

    static void addChildClasses() {
        querySelectorAll(".tt *")
            ..classes.add("tt-child")
            ..forEach((el) {
            el.classes.add("tt-child");
        });
    }

    static void addCloseListener(Function listener) {
        closeListener = listener;
    }

    static void highlightByIndex(int i, Map options) {
        if (i <= index) {
            lastOptions = options;

            Element el = querySelector(".t-" + i.toString());
            if (el != null) {
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
    }

    static void removeHighlighting(int i, [Function callback]) {
        if (i <= index && lastOptions != null) {
            Element overlay = querySelector(".overlay");
            if (overlay != null) {
                overlay.remove();
            }

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

            new Timer(new Duration(milliseconds: 200), callback != null ? callback : () {
            });
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
        querySelectorAll(".tt").forEach((Element el) {
            closeByIndex(int.parse(el.dataset['index']));
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
        return new Position(box.left + window.pageXOffset - docElem.clientLeft, box.top + window.pageYOffset - docElem.clientTop);
    }
}
