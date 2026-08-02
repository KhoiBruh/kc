struct Resource(id: i32) {
    fn free(self) {}
}

fn inspect<T: any>(val value: T) {}
fn consume(value: Resource) {}

fn main() {
    var value = Resource(1);
    inspect(value);
    consume(value);
}
