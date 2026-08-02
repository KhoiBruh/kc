struct Resource(id: i32) {
    fn free(self) {}
}

struct Sink() {
    fn consume(val self, value: Resource) {}
}

fn main() {
    val sink = Sink();
    var value = Resource(1);
    sink.consume(value);
    sink.consume(value);
}
