fn main() {
    var count: i32 = 1;
    count += 2;
    val ratio: f64 = 1;
    val optional: i32? = null;
    val empty: i32[] = [];
    later(count);
}

fn later(val value: i32): i32 {
    return value;
}
