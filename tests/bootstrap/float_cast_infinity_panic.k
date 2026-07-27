fn checked(val value: f64): i32 {
    return value as i32;
}

fn main(): i32 {
    return checked(1.0 / 0.0);
}
