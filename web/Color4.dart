import 'package:box2d/box2d_browser.dart';

class Color4 {
    int x;
    int y;
    int z;
    double a = 1.0;

    Color4() : x = 0, y = 0, z = 0;
    Color4.fromRGB(int r, int g, int b) : x = r, y = g, z = b;
    Color4.fromRGBA(this.x, this.y, this.z, this.a);
    Color4.fromRGBF(double r, double g, double b)
    : x = (r * 255).floor().toInt(),
    y = (g * 255).floor().toInt(),
    z = (b * 255).floor().toInt();
    Color4.fromColor3(Color3 color)
    : x = color.x, y = color.y, z = color.z;

    Color4.fromColor4(Color4 color)
    : x=color.x, y=color.y, z=color.z, a = color.a;

    void setFromRGB(int r, int g, int b) {
        x = r; y = g; z = b;
    }

    void setFromRGBA(int r, int g, int b, double a) {
        x = r;
        y = g;
        b = b;
        this.a = a;
    }

    void setFromRGBF(double r, double g, double b) {
        x = (r * 255).floor().toInt();
        y = (g * 255).floor().toInt();
        z = (b * 255).floor().toInt();
    }

    void setFromColor3(Color3 color) {
        x = color.x;
        y = color.y;
        z = color.z;
    }

    bool operator ==(final other) {
        return other is Color3 && x == other.x && y == other.y && z == other.z && a == other.a;
    }
}
