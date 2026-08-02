struct Resource(id: i32) {
    fn free(self) {}
}

fn consume(value: Resource) {}

fn main() {
    var value = Resource(1);
    var first = value;
    value = Resource(2);
    consume(value);
}
