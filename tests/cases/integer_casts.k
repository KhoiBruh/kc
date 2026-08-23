fn narrow(value: u64): u8 { return value as u8; }
fn signedToUnsigned(value: i32): u32 { return value as u32; }

fn main(): i32 {
    val narrowed = narrow(42) as i32;
    return signedToUnsigned(narrowed) as i32;
}
