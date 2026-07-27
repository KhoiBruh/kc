fn checked(val value: f64): u8 {
    return value as u8;
}

fn main(): i32 {
    return checked(300.0) as i32;
}
