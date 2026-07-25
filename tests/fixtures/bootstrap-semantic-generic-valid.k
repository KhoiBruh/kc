fn identity<T>(value: T): T {
    return value;
}

fn max<T: ordered>(a: T, b: T): T {
    if (a > b) {
        return a;
    }
    return b;
}

fn main(): i32 {
    return max(identity(40), identity<i32>(2));
}
