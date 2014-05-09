import "dart:html";
import "dart:async";
import 'dart:convert';

class Chapter {
  static List chapters;

  static void load(Function ready) {
    HttpRequest.getString("levels/chapters.json").then((String str) {
      chapters = JSON.decode(str)["chapters"];
      ready(chapters);
    });
  }
}
