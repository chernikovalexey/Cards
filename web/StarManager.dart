import "dart:html";
import "dart:convert";

class StarManager {
    static int total = 0;
    static Map byChapters;

    static void init() {
        if (window.localStorage['stars'] != null) {
            load();
        } else {
            byChapters = new Map();
        }
    }

    static void load() {
        Map m = JSON.decode(window.localStorage['stars']);
        byChapters = new Map();
        total = m['total'];
        for (var c in m['chapters']) {
            byChapters[c['id']] = c['s'];
        }
    }

    static void setResult(int chapter, int result) {
        print("set result = " + result.toString());
        if (result < 0) {
            result = 0;
        }

        byChapters[chapter] = result;
        total = 0;

        byChapters.forEach((k, v) {
            total += v;
        });

        save();
    }

    static void saveFrom(int chapter, List levels) {
        setResult(chapter, 0);
        for (int i = 0, len = levels.length;i < len;++i) {
            updateResult(chapter, levels[i].rating);
        }
    }

    static int getResult(int chapter) {
        if (byChapters[chapter] != null) {
            return byChapters[chapter];
        }
        return 0;
    }

    static void updateResult(int chapter, int delta) {
        setResult(chapter, getResult(chapter) + delta);
    }

    static void save() {
        Map m = new Map();
        m['total'] = total;
        List c = new List();
        byChapters.forEach((k, v) {
            c.add({
                "id":k, "s":v
            });
        });

        m['chapters'] = c;
        window.localStorage['stars'] = JSON.encode(m);
    }
}


