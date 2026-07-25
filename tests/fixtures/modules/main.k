module test.main;
import test.math.add;
import test.math.mul;
fn main(): i32 { return mul(add(1, 2), 4); }