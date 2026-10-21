/** Fixed-step 1 kHz physics accumulator with render interpolation alpha. */
export class SimulationLoop {
  readonly dt = 0.001; acc = 0; time = 0; steps = 0; maxSteps = 60;
  /** advances by real frame time, calling step() for each 1 ms tick. Returns interpolation alpha. */
  advance(frame: number, step: (dt: number, t: number) => void): number {
    this.acc += Math.min(frame, 0.08);
    let n = 0;
    while (this.acc >= this.dt && n < this.maxSteps) { step(this.dt, this.time); this.time += this.dt; this.acc -= this.dt; n++; }
    if (n === this.maxSteps) this.acc = 0;
    this.steps = n; return this.acc / this.dt;
  }
}
