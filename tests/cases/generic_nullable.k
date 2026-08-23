fn maybe<T>(value: T, enabled: bool): T? {
    if (enabled) {
        return value;
    }
    return null;
}

fn main(): i32 {
    val value = maybe<i32>(42, true);
    return value!;
}
