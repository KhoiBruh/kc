import bootstrap.heap.alloc;
import bootstrap.heap.free;
import bootstrap.heap.grow;

struct Point(x: i32, y: i32)

fn main(): i32 {
    val values = alloc<i32>(4);
    values[0] = 7;
    values[1] = 10;
    values[2] = 15;
    values[3] = 20;
    val sum = values[0] + values[1] + values[2] + values[3];
    if (sum != 52) return 1;

    val grown = grow<i32>(values, 4, 8);
    grown[4] = 6;
    if (grown[3] != 20) return 2;
    if (grown[4] != 6) return 3;
    free<i32>(grown);

    val points = alloc<Point>(2);
    points[0] = Point(3, 4);
    points[1] = Point(5, 6);
    if (points[1].x + points[1].y != 11) return 4;

    val moved = grow<Point>(points, 2, 4);
    if (moved[0].x != 3) return 5;
    if (moved[1].y != 6) return 6;
    moved[3] = Point(-1, 1);
    if (moved[3].x + moved[3].y != 0) return 7;
    free<Point>(moved);

    return 0;
}
