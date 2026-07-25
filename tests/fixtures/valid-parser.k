fn add(val left: i32, val right: i32): i32 {
    return left + right;
}

fn main() {
    val answer: i32 = add(1, 2 * 3);
    var converted = answer as f64;
    converted += 1;
}
