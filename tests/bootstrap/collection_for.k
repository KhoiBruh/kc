fn sum_slice(players: []i32): i32 {
    var total = 0;
    for (player, i in players) {
        total = total + player + i as i32;
    }
    return total;
}

fn main(): i32 {
    val empty: i32[0] = [];
    for (player in empty) return 1;
    val players = [10, 20, 9];
    var total = 0;
    for (player in players) total = total + player;
    for (player, i in players) {
        if (i == 1) {
            total = total + 3;
            break;
        }
    }
    return total;
}
