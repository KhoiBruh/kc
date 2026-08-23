import bootstrap.list.List;

struct Wrap(data: List<i64>) {
    fn count(val self): u64 => self.data.length;
}

struct Meter(count: i64) {
    fn doubled(val self): i64 => self.count * 2;
}

fn sizeOf(items: List<i64>): u64 => Wrap(items).count();

fn direct(): i64 => Meter(21).doubled();

fn main(): i32 {
    if (sizeOf(List<i64>.new()) != 0) return 1;
    var moved = List<i64>.new();
    moved.add(9);
    if (sizeOf(moved) != 1) return 2;
    if (direct() != 42) return 3;
    val m = Meter(20);
    if (m.doubled() != 40) return 4;
    var fresh = List<i64>.new();
    fresh.add(5);
    val localWrap = Wrap(fresh);
    if (localWrap.count() != 1) return 5;
    return 42;
}
