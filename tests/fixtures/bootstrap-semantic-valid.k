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
