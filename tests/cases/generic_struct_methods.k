struct Box<T>(value: T) {
    fn read(val self): T => self.value;
    fn replace(var self, value: T) { self.value = value; }
}

struct Pair<A, B>(first: A, second: B) {
    fn secondValue(val self): B => self.second;
}

fn main(): i32 {
    var box: Box<i32> = Box<i32>(41);
    box.replace(42);
    val pair: Pair<i32, bool> = Pair<i32, bool>(0, true);
    if (pair.secondValue() == false) return 0;
    return box.read();
}
