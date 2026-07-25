fn main(): i32 {
    var value = 0;
    if (value < 1) {
        value = value + 1;
    } else {
        return 1;
    }
    while (value < 2) {
        value = value + 1;
    }
    print(value);
    return 0;
}
