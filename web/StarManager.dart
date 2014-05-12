import "dart:html";
import "dart:convert";

class StarManager {
    int total = 0;
    Map byChapters;

    StarManager() {
        if(window.localStorage['stars']!=null) {
            load();
        } else
            byChapters = new Map();
    }

    void load() {
        Map m = JSON.decode(window.localStorage['stars']);
        byChapters = new Map();
        total = m['total'];
        for(var c in m['chapters']) {
            byChapters[c['id']] = c['s'];
        }
    }

    void setResult(int chapter, int result) {
        byChapters[chapter] = result;
        total = 0;
        byChapters.forEach((k,v) {
            total+=v;
        });
        save();
    }

    int getResult(int chapter) {
        if(byChapters[chapter]!=null) {
            return byChapters[chapter];
        }
        return 0;
    }

    void updateResult(int chapter, int delta) {
        setResult(chapter, getResult(chapter) + delta);
    }

    void save() {
        Map m = new Map();
        m['total'] = total;
        List c = new List();
        byChapters.forEach((k, v) {
            c.add({"id":k, "s":v});
        });

        m['chapters'] = c;
        window.localStorage['stars'] = JSON.encode(m);
    }
}
