import "dart:html";
import "GameEngine.dart";
import 'dart:js';
import 'package:animation/animation.dart';
import 'dart:async';

class PromptWindow {
    static int id = 1;
    static bool opened = false;

    static int __show(String sel, Object temp) {
        if (opened) return -1;

        opened = true;

        String template = querySelector(sel).innerHtml;
        String window = context['TemplateEngine'].callMethod('parseTemplate', [template, new JsObject.jsify(temp)]);
        Element body = querySelector('body');
        body.appendHtml(window);

        Element win = querySelector(".p-" + id.toString());
        win.style.opacity = "0.0";
        win.style.top = "150px";

        win.querySelector(".prompt-close").addEventListener("click", (event) {
            PromptWindow.close();
        }, true);

        animate(win, properties: {
            'opacity': 1.0, 'top': 200
        }, duration: 125, easing:Easing.SINUSOIDAL_EASY_IN);

        ++id;

        return id - 1;
    }

    static void show(String headline, String message, String offer_text, String offer_button, Function offerCallback, Function callback, [String positive="Yes", String negative="No"]) {
        String nid = __show(".prompt-window-template", {
            'id': id, 'headline': headline, 'message': message, 'offer_text': offer_text, 'offer_button': offer_button, 'positive': positive, 'negative': negative
        }).toString();

        querySelector(".po-" + nid).addEventListener("click", offerCallback, true);

        querySelector(".pp-" + nid).addEventListener("click", (event) {
            callback(true);
        }, true);

        querySelector(".pn-" + nid).addEventListener("click", (event) {
            callback(false);
        }, true);
    }

    static void showSimple(String headline, String message, String buttonLabel, Function callback) {
        String nid = __show(".simple-window-template", {
            'id': id, 'headline': headline, 'message': message, 'buttonLabel': buttonLabel
        }).toString();

        querySelector(".btn-" + nid).addEventListener("click", (event) {
            PromptWindow.close();
            callback();
        }, true);
    }

    static void close() {
        if (!opened) return;

        opened = false;

        Element win = querySelector(".p-" + (id - 1).toString());

        animate(win, properties: {
            'opacity': 0.0
        }, duration: 125, easing: Easing.SINUSOIDAL_EASY_IN);

        new Timer(new Duration(milliseconds: 125), () {
            win.remove();
        });
    }
}