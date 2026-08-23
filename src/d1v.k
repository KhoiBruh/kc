module d1v;

import bootstrap.list.List;

struct Wrap(data: List<i64>) {
    fn count(val self): u64 => self.data.length;
}

fn makeWrap(items: List<i64>): Wrap => Wrap(items);

fn sizeOfDirect(items: List<i64>): u64 => Wrap(items).count();

fn main(): i32 {
    val w = Wrap(List<i64>.new());
    if (w.count() == 0) return 42;
    return 1;
}
