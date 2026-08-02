struct Resource(id: i32) {
    fn free(self) {}
}

struct Sink() {
    fn consume(value: Resource) {}
}

fn main() {
    var value = Resource(1);
    Sink.consume(value);
    Sink.consume(value);
}
