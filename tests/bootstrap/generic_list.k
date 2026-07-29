import kbootstrap.list.List;
import kbootstrap.list.listAdd;
import kbootstrap.list.listFree;
import kbootstrap.list.listNew;

fn main(): i32 {
    var values: List<i32> = listNew<i32>(sizeof(i32));
    listAdd<i32>(values, 20);
    listAdd<i32>(values, 20);
    listAdd<i32>(values, 2);
    val result = values.data[0] + values.data[1] + values.data[2];
    var wide: List<u64> = listNew<u64>(sizeof(u64));
    listAdd<u64>(wide, 1);
    listAdd<u64>(wide, 2);
    listFree<i32>(values);
    listFree<u64>(wide);
    return result;
}
