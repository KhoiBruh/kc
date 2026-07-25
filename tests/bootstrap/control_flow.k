fn main(): i32 {
    var value = 0;
    while (value < 5) {
        if (value == 3) {
            return value;
        }
        value = value + 1;
    }
    return value;
}
