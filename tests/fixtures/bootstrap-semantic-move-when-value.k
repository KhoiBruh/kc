struct Resource(id: i32) {
    fn free(self) {}
}

fn main(val condition: bool) {
    var value = Resource(1);
    var selected = when (condition) {
        true -> value;
        else -> Resource(2);
    };
    var second = value;
}
