fn add(val a: i32, val b: i32): i32 => a + b;
extern fn k_boot_free(value: unit*);
fn answer() => add(40, 2);
fn release(value: unit*) => k_boot_free(value);
fn assign(a: i32, b: i32) => a = b;
fn assign_if(a: i32, b: i32) => if (a != b) a = b;

fn main(): i32 => answer();
