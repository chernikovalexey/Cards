import "dart:html";
import 'dart:js';

class UserManager {
    static String get(String key) {
        return context['Features']['user'][key];
    }

    static int getAsInt(String key) {
        return get(key) is int ? get(key) : int.parse(get(key));
    }

    static void set(String key, String val) {
        context['Features']['user'][key] = val;
    }

    static bool decrement(String key) {
        int attempts = getAsInt(key);
        if (attempts > 0) {
            set(key, (attempts - 1).toString());
        }
    }
}