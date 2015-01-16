import "dart:math";
import "dart:core";

class ChanceEngine {
    static Random r = new Random();

    static bool IsFired(double chance) {

        return r.nextDouble() < chance;
    }

    static Object InvokeFired(List<double> chances, List<Function> functions) {

        int id = SelectFired(chances);
        return functions[id]();
    }

    static int SelectFired(List<double> chances, [List results = null]) {

        double t = r.nextDouble();
        double ch = 0.0;
        for (int i = 0;i < chances.length;i++) {
            ch += chances[i];
            if (t < ch)return results != null ? results[i] : i;
        }
        return chances.length;
    }

}
