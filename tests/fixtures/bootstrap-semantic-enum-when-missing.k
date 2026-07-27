enum Status { Ready, Running, Done }

fn score(status: Status): i32 {
    return when (status) {
        Status.Ready -> 1;
        Status.Done -> 3;
    };
}
