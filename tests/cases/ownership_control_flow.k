struct Resource(id: i32) {
    fn free(self) {}
}

struct Holder(value: Resource, ok: bool)

fn consume(resource: Resource) => resource.id;

fn main(): i32 {
    var holder = Holder(Resource(42), true);
    if (!holder.ok) return 1;
    val value = holder.value;
    var index = 0;
    while (index < 1) {
        if (index == 2) return 2;
        index++;
    }
    while (index < 2) {
        return consume(value);
    }
    return 0;
}
