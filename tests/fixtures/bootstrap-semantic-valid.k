fn main(): i32 {
    val value = 1;
    {
        val value = 2;
        value + 1;
    }
    return add(40, 2);
}

fn add(val left: i32, val right: i32): i32 {
    return left + right;
}

fn recurse(val value: i32): i32 {
    if (value == 0) { return 0; }
    return recurse(value - 1);
}

extern fn consume(val data: []u8);

fn floatCasts(val small: f32, val wide: f64, val integer: i32): f64 {
    val identity = small as f32;
    val extended = small as f64;
    val narrowed = wide as f32;
    val fromInteger = integer as f64;
    val negativeFraction = -0.5 as u8;
    val signedMinimum = -2147483648.9 as i32;
    val checked = wide as i32;
    return extended;
}
