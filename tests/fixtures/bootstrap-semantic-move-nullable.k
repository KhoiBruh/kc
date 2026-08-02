struct Resource(id: i32) {
    fn free(self) {}
}

fn main() {
    var value: Resource? = Resource(1);
    var first = value!;
    var second = value!;
}
