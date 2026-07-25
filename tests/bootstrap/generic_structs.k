struct Pair<A, B>(first: A, second: B)

fn main(): i32 {
    val pair: Pair<i32, bool> = Pair<i32, bool>(40, true);
    var result = pair.first;
    if (pair.second) {
        result = result + 2;
    }
    return result;
}
