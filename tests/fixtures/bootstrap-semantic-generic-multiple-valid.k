fn keepSecond<A, B>(first: A, second: B): B {
    return second;
}

fn main(): i32 {
    return keepSecond(true, 42);
}
