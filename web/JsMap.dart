import 'dart:collection' show Maps;
import 'dart:js';

class JsMap implements Map<String, dynamic> {
    final JsObject _jsObject;

    JsMap.fromJsObject(this._jsObject);

    operator [](String key) => _jsObject[key];

    void operator []=(String key, value) {
        _jsObject[key] = value;
    }

    remove(String key) {
        final value = this[key];
        _jsObject.deleteProperty(key);
        return value;
    }

    Iterable<String> get keys => context['Object'].callMethod('keys', [_jsObject]);

    bool containsValue(value) => Maps.containsValue(this, value);

    bool containsKey(String key) => keys.contains(key);

    putIfAbsent(String key, ifAbsent()) => Maps.putIfAbsent(this, key, ifAbsent);

    void addAll(Map<String, dynamic> other) {
        if (other != null) {
            other.forEach((k, v) => this[k] = v);
        }
    }

    void clear() => Maps.clear(this);

    void forEach(void f(String key, value)) => Maps.forEach(this, f);

    Iterable get values => Maps.getValues(this);

    int get length => Maps.length(this);

    bool get isEmpty => Maps.isEmpty(this);

    bool get isNotEmpty => Maps.isNotEmpty(this);
}