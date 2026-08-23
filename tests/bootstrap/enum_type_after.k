module tests.bootstrap.enum_type_after;

struct Holder(kind: TestKind)

enum TestKind { Alpha, Beta }

fn identity(kind: TestKind): TestKind {
    return kind;
}

fn main(): i32 {
    val holder = Holder(identity(TestKind.Beta));
    return when (holder.kind) {
        TestKind.Alpha -> 0;
        TestKind.Beta -> 42;
    };
}
