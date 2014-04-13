import "dart:math" as Math;

class DoubleAnimation {
  bool isFinished = false;

  int frame = 0;

  int numFrames;

  double start, end;
  double lastDelta;
  double lastValue;

  DoubleAnimation(double start, double end, int numFrames) {
    this.start = start;
    this.end = end;
    this.lastDelta = 0.0;
    this.lastValue = start;
    if (start == end) isFinished = true;
    this.numFrames = numFrames;
  }

  double next() {
    isFinished = frame >= numFrames;
   
    if (isFinished) return end;
    
    double val = start + (end - start) * Math.sin(frame / numFrames * Math.PI /
        2);
    lastDelta = val - lastValue;
    lastValue = val;
    frame++;
    return val;
  }

  void setFrames(int frames) {
    this.numFrames = frames;
  }
  
  void setFrame(int frame) {
    this.frame = 0;
  }

  void setStart(double start) {
    this.start = start;
  }

  void setEnd(double end) {
    this.end = end;
    this.isFinished = false;
  }

  void modify(double newEnd, int newFrameCount) {
    this.end = newEnd;
    this.numFrames = newFrameCount;
  }
}
