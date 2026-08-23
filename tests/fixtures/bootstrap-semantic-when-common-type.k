fn main(): i32 {
    var label: u64 = 0;
    val wide: u64 = 7;
    label = when (wide > 3) {
        true -> 5;
        false -> wide;
    };
    if (label == 5) return 42;
    return 1;
}
