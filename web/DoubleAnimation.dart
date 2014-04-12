import "dart:math" as Math;

class DoubleAnimation {
    bool isFinished = false;

    int frame = 0;

    int numFrames;

    double start, end;
    double lastDelta;
    double lastValue;

    DoubleAnimation(double start, double end, int numFrames)
    {
        this.start = start;
        this.end = end;
        this.lastDelta = 0;
        this.lastValue = start;
        if (start == end) isFinished = true;
        this.numFrames = numFrames;
    }

    double next()
    {
        if (isFinished) return end;
        double val = start + (end - start) * Math.sin(frame / numFrames * Math.PI / 2);
        lastDelta = val - lastValue;
        lastValue = val;
        frame++;
        isFinished = frame == numFrames;
        return val;
    }

    void modify(double newEnd, int newFrameCount)
    {
        end = newEnd;
        numFrames = newFrameCount;
    }
}
