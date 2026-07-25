fn update(val opaque: unit*, val index: i64): i32 {
    val values = opaque as i32*;
    values[index] = 42;
    return values[index];
}
