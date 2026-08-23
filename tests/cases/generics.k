fn identity<T>(value: T): T {
    return value;
}

fn twice<T>(value: T): T {
    return identity<T>(identity<T>(value));
}

fn add<T: number>(a: T, b: T): T {
    return a + b;
}

fn main(): i32 {
    return add(twice(20), identity<i32>(2));
}
