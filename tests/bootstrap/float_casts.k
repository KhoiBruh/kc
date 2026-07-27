fn checked(val value: f64): i32 {
    return value as i32;
}

fn main(): i32 {
    val signed = 40 as f64;
    val unsigned: u32 = 2;
    val narrowed = signed as f32;
    val extended = narrowed as f64;
    val negativeFraction = checked(-0.5);
    return checked(
        extended + (unsigned as f64) + 0.75 +
        (negativeFraction as f64));
}
