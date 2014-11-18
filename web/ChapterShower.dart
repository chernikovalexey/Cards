import "dart:html";
import 'cards.dart';
import 'Scroll.dart';
import 'dart:js';
import 'Chapter.dart';
import "StarManager.dart";
import 'Input.dart';
import "WebApi.dart";

class ChapterShower {
    static void show(List chapters) {
        querySelector("#chapter-es").innerHtml = "";

        Input.attachSingleEscClickCallback(() {
            querySelector(".go-to-menu-button").click();
        });

        int id = 0;
        for (Map chapter in chapters) {
            querySelector("#chapter-es").appendHtml(chapterItem(chapter, ++id));
        }

        var bar = Scroll.setup('chapter-vs', 'chapter-es', 'chapter-scrollbar');
        context['dw_Scrollbar_Co'].callMethod('addEvent', [bar, 'on_scroll', (var x, var y) {
            querySelector("#chapter-blur-g").style.transform = "translatey(" + (y + 76).toString() + "px)";
        }]);

        context.callMethod('html2canvas', [querySelector('.chapter-list'), new JsObject.jsify({
            'onrendered': (CanvasElement canvas) {
                canvas.id = "chapter-blur-g";
                querySelector(".chapter-blurry-bar").append(canvas);
                CanvasRenderingContext2D g = canvas.getContext('2d');
                g.fillStyle = 'rgba(0, 0, 0, 0.5)';
                g.fillRect(0, 0, canvas.width, canvas.height);
            }
        })]);

        querySelectorAll(".chapter").forEach((DivElement e) {
            e.addEventListener("click", (event) {
                if (!e.classes.contains("chapter-locked")) {
                    Input.removeSingleEscClickCallback();
                    int chapter = int.parse(e.dataset["id"]);
                    manager.removeState(engine); // ???
                    manager.addState(engine, {
                        'chapter': chapter
                    });
                    updateCanvasPositionAndDimension();

                    querySelector("#chapter-selection").classes.add("hidden");
                    querySelector(".buttons").classes.remove("hidden");
                    querySelector(".selectors").classes.remove("hidden");

                    // update only on enter to the game state
                    updateAttempts();
                } else {
                    WebApi.unlockChapter(e.dataset['id']);
                    WebApi.onOrderSuccess(() {
                        print("order success!");
                        Chapter.load(show);
                    });
                }
            }, false);
        });

        querySelector(".go-to-menu-button").addEventListener("click", (event) {
            fadeBoxOut(querySelector("#chapter-selection"), 125, () {
                showMainMenu();
            });
        }, false);
    }

    static String chapterItem(Map chapter, int id) {
        DivElement el = querySelector(".chapter-template") as DivElement;
        el.querySelector(".chapter").dataset["id"] = id.toString();
        el.querySelector(".chapter-title").innerHtml = chapter["name"];

        int totalStars = StarManager.total;
        bool unlocked = chapter["unlocked"];

        if (!unlocked) {
            int left = chapter["unlock_stars"] - totalStars;
            el.querySelector(".stars-left").innerHtml = left.toString();
            el.querySelector(".word-ending").hidden = left == 1;
            el.querySelector(".chapter").classes.add("chapter-locked");
        } else {
            int finished = Chapter.getFinishedLevelsAmount(id, chapter["levels"]);

            el.querySelector(".chapter").classes.remove("chapter-locked");
            el.querySelector(".current-bar").style.width = (240 * finished / chapter["levels"]).toString() + "px";
            el.querySelector(".finished-levels").innerHtml = finished.toString();
            el.querySelector(".all-levels").innerHtml = chapter["levels"].toString();

            el.querySelector(".earned-stars").innerHtml = StarManager.getResult(id).toString();
        }

        return el.innerHtml;
    }
}
