enum Status { Ready, Done }

fn score(status: Status): i32 {
    return when (status) {
        Status.Ready -> 1;
        Status.Ready -> 2;
        else -> 3;
    };
}
