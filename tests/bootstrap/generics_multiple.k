fn keepSecond<A, B>(first: A, second: B): B {
    return second;
}

fn forward<A, B>(first: A, second: B): B {
    return keepSecond<A, B>(first, second);
}

fn keepThird<A, B, C>(first: A, second: B, third: C): C {
    return third;
}

fn forwardThird<A, B, C>(first: A, second: B, third: C): C {
    return keepThird<A, B, C>(first, second, third);
}

fn main(): i32 {
    val pair = forward<bool, i32>(true, 20);
    val triple =
        forwardThird<bool, i64, i32>(false, 64, 22);
    return pair + triple;
}
