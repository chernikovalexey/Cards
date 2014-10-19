import "dart:html";
import "GameEngine.dart";
import 'dart:js';

class PromptWindow {
    static int id = 1;

    static void show(String headline, String message, Function callback, [String positive, String negative]) {
        String template = querySelector(".prompt-window-template").innerHtml;
        String window = context['TemplateEngine'].callMethod('parseTemplate', [template, new JsObject.jsify({
            'id': id, 'headline': headline, 'message': message, 'positive': "Yes", 'negative': "No"
        })]);
        Element body = querySelector('body');
        body.appendHtml(window);

        querySelector(".pp-" + id.toString()).addEventListener("click", (event) {
            callback(true);
        }, true);

        querySelector(".pn-" + id.toString()).addEventListener("click", (event) {
            callback(false);
        }, true);

        ++id;
    }

    static void close() {
        querySelector(".p-" + (id - 1).toString()).remove();
    }
}