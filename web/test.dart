import "DoubleAnimation.dart";

void main() {
    DoubleAnimation a = new DoubleAnimation(0.0,10.0,10);
    for(int i=0;i<15;i++) {
        print(a.next());
    }
}