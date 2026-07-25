fn first(val values: []i32): i32 {
    return values[0];
}

fn main(): i32 {
    val values: i32[2] = [1, 2];
    val view: []i32 = values;
    print(first(view));
    return 0;
}
