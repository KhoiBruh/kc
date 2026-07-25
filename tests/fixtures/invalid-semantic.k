fn broken() {
    val value = 1;
    val value = 2;
    value = 3;
    missing;
    accepts(true);
    return 1;
}

fn accepts(val value: i32) {}
