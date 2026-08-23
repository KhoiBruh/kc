struct Counter(value: i32) {
    fn read(val self): i32 => self.value;
    fn increment(var self) { self.value++; }
}

fn main(): i32 {
    var counter = Counter(41);
    counter.increment();
    return counter.read();
}
