import bootstrap.list.List;

fn main(): i32 {
    var values: List<i32> = List<i32>.new();
    values.add(20);
    values.add(20);
    values.add(2);
    val result = values.data[0] + values.data[1] + values.data[2];
    var wide: List<u64> = List<u64>.new();
    wide.add(1);
    wide.add(2);
    values.free();
    wide.free();
    return result;
}
