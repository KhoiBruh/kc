fn main(): i32 {
    val values: i32[1] = [1];
    val view: []i32 = values;
    return view[2];
}
