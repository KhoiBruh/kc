fn main(): i32 {
    val byte: u8 = 10;
    var value: u64 = byte + 6;
    value = value * 2 + byte;
    return value as i32;
}
