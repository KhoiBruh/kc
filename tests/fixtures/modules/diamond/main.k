module diamond.main;
import diamond.a.runA;
import diamond.b.runB;
fn main(): i32 { return runA() + runB(); }
