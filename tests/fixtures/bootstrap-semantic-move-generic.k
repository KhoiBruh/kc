struct Resource(id: i32) {
    fn free(self) {}
}

fn consume<T: any>(value: T) {}

fn main() {
    var value = Resource(1);
    consume(value);
    consume(value);
}
