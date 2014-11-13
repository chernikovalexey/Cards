import "dart:html";
import 'dart:js';

class UserManager {
    static dynamic get(String key) {
        return context['Features']['user'].hasProperty(key) ? context['Features']['user'][key] : 0;
    }

    static int getAsString(String key) {
        return get(key) is int ? get(key).toString() : get(key);
    }

    static int getAsInt(String key) {
        print(get(key) is int);
        print(get(key));
        return get(key) is int ? get(key) : int.parse(get(key));
    }

    // sets an integer

    static void set(String key, int val) {
        context['Features']['user'][key] = val;
    }

    static bool decrement(String key) {
        int attempts = getAsInt(key);
        if (attempts > 0) {
            set(key, attempts - 1);
            return true;
        }
        return false;
    }
}