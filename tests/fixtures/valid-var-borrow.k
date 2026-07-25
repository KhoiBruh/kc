fn increment(var value: i32) {
    value = value + 1;
}

fn main(): i32 {
    var value = 41;
    increment(value);
    print(value);
    return 0;
}
