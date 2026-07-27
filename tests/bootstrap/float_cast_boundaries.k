fn toI32F64(val value: f64): i32 { return value as i32; }
fn toI64F64(val value: f64): i64 { return value as i64; }
fn toU8F64(val value: f64): u8 { return value as u8; }
fn toU32F64(val value: f64): u32 { return value as u32; }
fn toU64F64(val value: f64): u64 { return value as u64; }
fn toI32F32(val value: f32): i32 { return value as i32; }
fn toU32F32(val value: f32): u32 { return value as u32; }

fn main(): i32 {
    val i32Minimum = toI32F64(-2147483648.9);
    val i32Maximum = toI32F64(2147483647.9);
    val i64Minimum = toI64F64(-9223372036854775808.0);
    val i64Maximum = toI64F64(9223372036854774784.0);
    val u8Fraction = toU8F64(-0.5);
    val u8Maximum = toU8F64(255.9);
    val u32Maximum = toU32F64(4294967295.9);
    val u64Maximum = toU64F64(18446744073709549568.0);
    val f32I32Minimum = toI32F32(-2147483648.0 as f32);
    val f32I32Maximum = toI32F32(2147483520.0 as f32);
    val f32U32Maximum = toU32F32(4294967040.0 as f32);
    return 42;
}
