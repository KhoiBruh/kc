struct Counter(value: i32) {
    fn new(value: i32): Counter => Counter(value);
}

struct Box<T>(value: T) {
    fn new(value: T): Box<T> => Box<T>(value);
    fn copyOf(val source: Box<T>): Box<T> => Box<T>(source.value);
}

fn main(): i32 {
    val counter = Counter.new(1);
    val box = Box<i32>.new(42);
    val copied = Box<i32>.copyOf(box);
    if (counter.value != 1) return 0;
    return copied.value;
}
