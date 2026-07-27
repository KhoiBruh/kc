# Đặc tả thiết kế ngôn ngữ K (K Programming Language)

## 1. Triết lý cốt lõi

**K** là một ngôn ngữ hệ thống, biên dịch tĩnh qua LLVM, được thiết kế với các mục tiêu:

* **Hiệu năng tuyệt đối:** Không có Garbage Collector (GC), sử dụng Static Dispatch, cấu trúc bộ nhớ tương thích 100% với C ABI.
* **An toàn mặc định:** Quản lý tài nguyên qua mô hình RAII (new/free) và `defer`. Cấm biến toàn cục khả biến, bắt buộc khởi tạo bộ nhớ an toàn (Zero-initialization).
* **Cú pháp hiện đại:** Hướng đối tượng giả thủ tục (Procedural OOP), hỗ trợ suy luận kiểu, xử lý lỗi bằng Tagged Union và luồng điều khiển linh hoạt.

---

## 2. Hệ thống kiểu dữ liệu (Type System)

Raw pointer dùng cú pháp hậu tố `T*`. `unit*` là con trỏ opaque tương thích với
`void*` trong C ABI. Raw pointer không sở hữu tài nguyên và không được tự động
giải phóng; dereference, indexing và pointer arithmetic chỉ hợp lệ khi từng phép
toán được ngôn ngữ hỗ trợ rõ ràng.

Ngôn ngữ K hỗ trợ các kiểu dữ liệu nguyên thủy ánh xạ trực tiếp xuống LLVM IR:

| Nhóm | Kiểu dữ liệu | Mô tả |
| --- | --- | --- |
| **Logic** | `bool` | `true` hoặc `false` |
| **Số nguyên** | `i8`, `i16`, `i32`, `i64`, `i128` | Số nguyên có dấu |
| **Số nguyên dương** | `u8`, `u16`, `u32`, `u64`, `u128` | Số nguyên không dấu |
| **Số thực** | `f8`, `f16`, `f32`, `f64` | Phù hợp từ nhúng đến AI |
| **Ký tự** | `char` | Unicode scalar value 32-bit, lấy mã qua `char.code` |
| **Chuỗi** | `string` | Chuỗi UTF-8 sở hữu buffer và luôn hợp lệ |

### Ngữ nghĩa số học (Numeric Semantics)

Literal số được suy luận theo kiểu đích. Khi không có ngữ cảnh kiểu, literal số nguyên mặc định là `i32` và literal số thực mặc định là `f64`:

```text
val a = 1          // i32
val b = 1.5        // f64
val c: u8 = 10     // u8
val d: f32 = 1.5   // f32
val e: f64 = 1     // f64
```

Nếu literal không nằm trong miền của kiểu đích, trình biên dịch báo lỗi:

```text
val x: u8 = 300    // Lỗi biên dịch
val y: i8 = -129   // Lỗi biên dịch
```

#### Promotion trong biểu thức

Các toán hạng số được tự động nâng lên một kiểu kết quả tĩnh theo các quy tắc sau:

* Hai integer cùng signedness được nâng lên kiểu có độ rộng lớn hơn.
* Signed integer và unsigned integer được nâng lên kiểu signed nhỏ nhất chứa được toàn bộ miền của cả hai kiểu, ví dụ `i16 + u16 -> i32`, `u8 + i16 -> i16`, `i64 + u64 -> i128`.
* Nếu không có kiểu integer chứa được toàn bộ miền của hai toán hạng, như `i128 + u128`, trình biên dịch báo lỗi và yêu cầu cast tường minh.
* Integer và float cho kết quả float. Float được nâng lên loại rộng hơn khi integer có độ rộng lớn hơn, tối đa là `f64`; ví dụ `f32 + i64 -> f64`. Nếu đã đạt `f64`, phép toán vẫn cho kết quả `f64` và có thể mất độ chính xác.
* Hai float được nâng lên kiểu float rộng hơn.
* Các phép so sánh số sử dụng cùng quy tắc promotion.
* Literal có thể thích nghi trực tiếp theo kiểu của toán hạng còn lại.

Promotion tự động chỉ xảy ra giữa các toán hạng trong biểu thức. Gán một biến sang kiểu số khác vẫn yêu cầu cast tường minh bằng `as`:

```text
val a: i32 = 1
val b: f64 = a as f64
```

#### Overflow và phép toán không hợp lệ

Các phép toán integer được kiểm tra overflow. Nếu kết quả sai có thể được xác định trong lúc biên dịch, trình biên dịch báo lỗi; nếu phụ thuộc dữ liệu runtime, chương trình sẽ `panic`.

Phép chia hoặc modulo cho `0`, cũng như shift với số bit âm hoặc lớn hơn hay bằng độ rộng của kiểu, tuân theo cùng quy tắc: lỗi biên dịch nếu biết trước, nếu không thì `panic` lúc chạy.

Phiên bản đầu tiên của K chưa cung cấp các phép toán wrapping, saturating hoặc checked riêng biệt.

#### Cast số

* Cast giữa các kiểu integer kiểm tra miền giá trị. Cast chắc chắn không hợp lệ gây lỗi biên dịch; cast chỉ thất bại với dữ liệu runtime sẽ `panic`.
* Cast float sang integer cắt phần thập phân về phía `0`. Giá trị ngoài miền integer, `NaN` hoặc infinity gây lỗi biên dịch nếu biết trước, nếu không thì `panic`.
* Cast từ float rộng xuống float hẹp tuân theo IEEE 754: làm tròn về giá trị gần nhất, giá trị hữu hạn quá lớn trở thành infinity, còn `NaN` và infinity được giữ nguyên. Phép cast này không `panic`.

Vertical slice đầu tiên chỉ triển khai cast tường minh giữa các kiểu integer
`i8`–`i128` và `u8`–`u128`:

| Nguồn → đích | Hành vi |
| --- | --- |
| Cùng kiểu | Identity, luôn thành công |
| Cùng signedness, đích rộng hơn | Luôn thành công |
| Unsigned → signed rộng hơn nguồn | Luôn thành công |
| Narrowing hoặc mọi đổi signedness còn lại | Kiểm tra miền giá trị |

Giá trị hằng nằm ngoài miền đích gây semantic diagnostic tại biểu thức cast.
Giá trị runtime nằm ngoài miền đích gọi `panic`; cast không được wrap hay
saturate. `bool`, `char`, float và pointer không tham gia ma trận integer này;
pointer cast hiện có vẫn là một contract riêng. Float casts được để lại cho
vertical slice sau khi integer casts đã self-hosted.

Frontend semantic của `kc0` và compiler bootstrap hiện áp dụng ma trận integer
trên, từ chối float cast trong slice này, báo constant ngoài miền tại toàn bộ
biểu thức cast, và lưu metadata cho biết conversion có cần runtime range check.
Cả LLVM backend C++ và textual bootstrap dùng identity/`sext`/`zext` cho cast
an toàn; narrowing hoặc đổi signedness được kiểm tra trước khi giá trị được sử
dụng và gọi `k_boot_panic` nếu ngoài miền.

### Văn bản và Unicode (Text & Unicode)

`char` biểu diễn đúng một Unicode scalar value và được lưu bằng 32 bit. `string` sở hữu một buffer UTF-8 hợp lệ; dữ liệu nhị phân sử dụng `[]u8` thay vì `string`.

#### Mutability và lưu trữ

`string` là một owned mutable buffer gồm độ dài và capacity. Binding `val` chỉ cho phép đọc string, còn binding `var` có thể thay đổi nội dung:

```text
var text = "abc"
text += "d"
```

Khi nối chuỗi, runtime tái sử dụng capacity còn lại nếu có. Nếu buffer không đủ chỗ, runtime cấp phát buffer lớn hơn, sao chép dữ liệu, thêm nội dung mới rồi giải phóng buffer cũ.

Không được sửa hoặc giải phóng string trong khi còn slice, iterator, C pointer hoặc borrow khác tham chiếu đến nội dung của nó. Trình biên dịch kiểm tra quy tắc này theo hệ thống borrow.

#### Truy cập nội dung

Không cho phép index trực tiếp bằng cú pháp `text[i]`. String cung cấp các API sau:

```text
text.charAt(i)   // char; panic nếu i ngoài phạm vi
text.getChar(i)  // char?; trả null nếu i ngoài phạm vi
text.bytes       // []u8 chỉ đọc; truy cập byte theo O(1)
text.chars       // Iterator<char>; decode UTF-8 tuần tự
text.length      // Số Unicode scalar; có thể O(n) hoặc lấy từ cache
text.byteLength  // Số byte UTF-8; O(1)
```

`substring(start, end)` nhận chỉ số theo `char`, với `end` không được bao gồm. Chỉ số ngoài phạm vi gây `panic`. Kết quả là một string mới sở hữu buffer độc lập với string ban đầu.

Phiên bản đầu tiên của K làm việc theo Unicode scalar, chưa hỗ trợ grapheme cluster. Vì vậy, một ký tự người dùng nhìn thấy có thể được tính thành nhiều `char`.

#### Literal, escape và interpolation

String literal dùng dấu nháy kép, còn char literal dùng dấu nháy đơn:

```text
val letter: char = 'ế'
val newline: char = '\n'
val text = "Hello\nK"
val symbol: char = '\u{1F600}'
```

Các escape được hỗ trợ gồm `\n`, `\r`, `\t`, `\0`, `\\`, `\"`, `\'` và `\u{HEX}`. Sau khi giải escape, char literal phải chứa đúng một Unicode scalar hợp lệ; literal rỗng, chứa nhiều scalar, surrogate hoặc code point không hợp lệ gây lỗi biên dịch.

String interpolation hỗ trợ identifier ngắn sau `$` và biểu thức phức tạp trong `${...}`:

```text
val message = "Language: $name, version: $version"
val detail = "Language: ${name.get()}"
val price = "Price: \$10"
```

Giá trị interpolation được chuyển thành string qua trait chuẩn `ToString`. Escape `\$` tạo ký tự `$` thông thường.

#### C interop và so sánh

Buffer của string luôn có một null terminator ẩn ở cuối; `byteLength` không tính byte này. String vẫn được phép chứa `\0` bên trong.

`cStr()` tạo một C-compatible borrowed pointer và trả fault nếu string chứa `\0` nội bộ. Pointer chỉ hợp lệ trong thời gian borrow; string không được sửa, move hoặc giải phóng trong thời gian đó.

Toán tử `==` so sánh chính xác nội dung Unicode scalar/UTF-8. K không tự động normalize hoặc case-fold, nên hai chuỗi nhìn giống nhau nhưng có encoding Unicode khác nhau có thể không bằng nhau. API grapheme, normalization và case-folding được để lại cho phiên bản sau.

**Mảng (Arrays):**

Mảng sử dụng cú pháp kiểu C, với kiểu phần tử đứng trước kích thước:

```text
val fixed: i8[5] = [0, 1, 2, 3, 4]
val runtime: i8[n] = createValues() // n có thể được xác định lúc chạy
val inferred: i8[] = [0, 1, 2]      // Suy luận thành i8[3]
```

* `T[N]` là mảng sở hữu dữ liệu. `N` có thể là hằng số thời gian biên dịch hoặc biểu thức được xác định lúc chạy.
* Khi bỏ qua kích thước trong `T[]`, trình biên dịch suy luận kích thước từ biểu thức khởi tạo. Vì vậy, khai báo này bắt buộc phải có giá trị khởi tạo.
* Mảng chỉ sống đến hết phạm vi khai báo. Trình biên dịch tự chọn cấp phát trên stack hoặc heap dựa trên kích thước và tự giải phóng khi mảng hết phạm vi.
* Nếu trình biên dịch chọn heap nhưng không thể cấp phát, chương trình sẽ `panic`.
* Slice sử dụng cú pháp `[]T`. Slice là một view gồm tham chiếu đến dữ liệu và độ dài, không sở hữu hay tự giải phóng dữ liệu:

```text
val values: i8[] = [0, 1, 2, 3]
val view: []i8 = values
```

Slice không được sống lâu hơn mảng hoặc vùng dữ liệu mà nó tham chiếu.

### Kiểu liệt kê (Enums)

`enum` định nghĩa một tập hợp hữu hạn các giá trị có tên:

```text
enum Status {
    OK,              // 0
    CREATED,         // 1
    NOT_FOUND = 404,
    SERVER_ERROR     // 405
}

val state: Status = Status.OK

enum CStatus: i32 {
    OK = 0,
    ERROR = -1
}
```

* Phần tử đầu tiên không được gán thủ công có giá trị `0`. Mỗi phần tử không được gán tiếp theo nhận giá trị của phần tử trước cộng `1`.
* Một enum có thể trộn phần tử được đánh số tự động và phần tử được gán số thủ công.
* Có thể ghi rõ kiểu số nền sau tên enum, ví dụ `enum CStatus: i32`. Mọi giá trị phải nằm trong miền của kiểu nền, nếu không trình biên dịch sẽ báo lỗi.
* Nếu không ghi kiểu nền, trình biên dịch chọn kiểu số nguyên nhỏ nhất chứa được toàn bộ giá trị. Enum có giá trị âm sử dụng kiểu có dấu; enum không có giá trị âm sử dụng kiểu không dấu.
* Enum dùng để tương tác với C phải ghi rõ kiểu nền; không được dựa vào kiểu do trình biên dịch suy luận.
* Mỗi giá trị enum phải được truy cập qua tên kiểu để tránh xung đột tên.
* Trình biên dịch kiểm tra đầy đủ các nhánh khi `when` hoạt động trên enum; nhánh `else` có thể được bỏ qua nếu mọi giá trị đã được xử lý.

### Kiểu nullable (Nullable Types)

Mọi kiểu `T` mặc định không thể nhận `null`. Chỉ kiểu `T?` mới có thể chứa một giá trị `T` hoặc `null`:

```text
fn findPlayer(id: i32): Player? {
    when (id) {
        1 -> return Player()
        else -> return null
    }
}

val optional: Player? = findPlayer(1)
val player: Player = optional! // Lấy Player hoặc panic nếu là null
```

* Không được gán `null` cho `T` và không được truy cập member hoặc gọi method trực tiếp trên `T?` trước khi kiểm tra hay unwrap.
* Toán tử `value!` unwrap nullable thành `T` và sẽ `panic` nếu giá trị là `null`.
* `when` tự thu hẹp kiểu trong nhánh chứa giá trị:

```text
when (optional) {
    null -> print("Không tìm thấy")
    value -> value.updateScore(1) // value có kiểu Player
}
```

* Nếu `T` là move-only và kết quả unwrap được truyền cho nơi nhận ownership, ownership được chuyển ra khỏi nullable; biến nullable không còn hợp lệ sau đó.
* Nếu kết quả unwrap chỉ được truyền vào tham số borrow `val` hoặc `var`, nullable vẫn giữ ownership và còn hợp lệ sau khi borrow kết thúc.
* Nullable lồng nhau như `T??` không hợp lệ và là lỗi biên dịch.
* Trình biên dịch có thể tối ưu cách biểu diễn `T?`, nhưng layout của nullable không mặc định tương thích với C ABI.

---

## 3. Biến và Phạm vi (Variables & Scope)

* **`val` (Bất biến):** Chỉ đọc, an toàn luồng.
* **`var` (Khả biến):** Có thể gán lại giá trị.
* **Suy luận kiểu (Type Inference):** Hỗ trợ suy luận kiểu khi khởi tạo rõ ràng (VD: `val a = true`, `val b = "text"`). Literal số nguyên không có ngữ cảnh mặc định là `i32`, còn literal số thực mặc định là `f64`.
* **Quy tắc phạm vi:** KHÔNG có biến toàn cục (global variables). Chỉ cho phép hằng số toàn cục bằng từ khóa `const`: `const MAX_SIZE: i32 = 100`.

### Ownership, Move và Borrow

Các từ khóa `val` và `var` đứng trước tham số xác định cách hàm mượn giá trị. Tham số không có `val` hoặc `var` sẽ nhận ownership:

```text
fn read(val player: Player) { ... }    // Mượn chỉ đọc
fn update(var player: Player) { ... }  // Mượn và được phép sửa
fn consume(player: Player) { ... }     // Nhận ownership
```

* Các kiểu số, `bool`, `char` và `enum` được copy ngầm vì không sở hữu tài nguyên.
* `string`, mảng và struct có `free()` là move-only. Phép gán hoặc truyền vào tham số nhận ownership sẽ tự động chuyển ownership sang biến hay hàm đích.
* Sau khi một giá trị đã được move, mọi lần sử dụng biến cũ đều là lỗi biên dịch.

```text
val a = Player()
val b = a          // Ownership được chuyển từ a sang b
a.updateScore(1)   // Lỗi biên dịch: a đã bị move

val c = b.copy()   // Tạo một deep copy độc lập; b vẫn hợp lệ
```

* `.copy()` sao chép toàn bộ dữ liệu được sở hữu sang vùng nhớ độc lập. Nếu không thể cấp phát bộ nhớ cho bản sao, chương trình sẽ `panic`.
* Có thể tồn tại nhiều borrow `val` của cùng một giá trị tại một thời điểm.
* Borrow `var` là độc quyền. Trong thời gian borrow này còn hiệu lực, không được tạo borrow khác hoặc truy cập trực tiếp owner.
* Borrow không được trả về, lưu vào struct hoặc sống lâu hơn owner. Các khả năng này chỉ được bổ sung khi K có hệ thống lifetime tường minh.
* Phiên bản đầu tiên của K không hỗ trợ shared ownership hoặc reference counting.

---

## 4. Hướng đối tượng giả thủ tục (Procedural OOP)

Mọi cấu trúc dữ liệu đều là `struct`. Các hàm viết bên trong `struct` thực chất là các hàm thủ tục nhận tham số `self`. Receiver `val self` mượn object chỉ đọc, `var self` mượn object để sửa, còn `self` không có modifier sẽ nhận ownership.

### Cú pháp cơ bản & RAII

Struct chỉ chứa dữ liệu có thể bỏ block body:

```text
struct Player(name: string, playtime: u32)
```

Dạng có body vẫn hợp lệ:

```text
struct Player(name: string, playtime: u32) {}
```

Hai dạng khai báo cùng layout field. Block body được dành cho constructor,
destructor và method khi các tính năng đó được triển khai.

```text
struct Player(
    name: string = "Unknown", // Hỗ trợ giá trị mặc định
    score: f32,
    buffer_id: u32
) {
    // Tự động gọi khi 'val p = Player()'
    override fn new() {
        self.buffer_id = glGenbuffers();
    }

    // Tự động gọi khi biến ra khỏi phạm vi (Scope)
    override fn free() {
        glDeleteBuffers(self.buffer_id);
    }

    // Mượn Player độc quyền trong thời gian gọi để thay đổi dữ liệu
    fn updateScore(var self, points: f32) {
        self.score = self.score + points;
    }
}

```

### Hàm mở rộng (Extension Functions)

Cho phép gắn thêm hàm vào bất kỳ kiểu dữ liệu nào (kể cả kiểu nguyên thủy):

```text
fn i32.isEven(): bool {
    return self % 2 == 0;
}
// Sử dụng: val a: i32 = 4; a.isEven();

```

---

## 5. Luồng điều khiển (Control Flow)

### Câu lệnh `if`

K hỗ trợ câu lệnh điều kiện quen thuộc cho luồng điều khiển tuần tự:

```text
if (condition) {
    runPrimaryPath();
} else {
    runFallbackPath();
}
```

Điều kiện phải có kiểu `bool`. Mỗi nhánh tạo một scope riêng. `if` không thay
thế `when`; `when` vẫn được dùng cho pattern-style branching và biểu thức nhiều
nhánh.

### Biểu thức `when`

Thay thế chuỗi điều kiện nhiều nhánh và `switch` truyền thống. Có thể dùng như
một biểu thức gán và hỗ trợ toán tử logic:

```text
// Thay thế switch (Biên dịch thành Jump Table)
val result = when (code) {
    200 -> "OK"
    404 -> "Not Found"
    else -> "Unknown" // Bắt buộc có else khi gán (Exhaustiveness checking)
}

// Thay thế if-else
when {
    a + b == c -> print("Match")
    a < b && c > b -> print("Between")
}

```

### Vòng lặp (Loops)

Sử dụng cú pháp dựa trên phạm vi (Ranges) và Iterator, loại bỏ vòng lặp `for` kiểu C:

* Đếm lên: `for (i in 0..10)` (từ 0 đến 10).
* Đếm giới hạn: `for (i in 0..<10)` (từ 0 đến 9).
* Duyệt mảng: `for (a in arr)`
* Duyệt mảng kèm chỉ số: `for (a, i in arr)`
* Vòng lặp điều kiện: `while (condition) { ... }`

---

## 6. Xử lý lỗi (Error Handling)

K sử dụng **Error Union Types** thay cho exception hoặc error code truyền thống. `fault` định nghĩa một kiểu lỗi có thể không mang dữ liệu hoặc chứa nhiều field:

```text
fault PLAYER_NOT_FOUND

fault IO_ERROR(
    code: i32,
    message: string
)

fault INVALID_FORMAT(line: i32)
```

Một hàm có thể trả về giá trị thành công hoặc một trong nhiều loại fault:

```text
fn load(): Player | IO_ERROR | INVALID_FORMAT {
    val data = readFile("player.dat")?
    return parsePlayer(data)?
}
```

* Toán tử `expr?` lấy giá trị thành công. Nếu biểu thức chứa fault, hàm hiện tại dừng và truyền fault đó cho caller.
* Chỉ được dùng `expr?` khi kiểu trả về của hàm hiện tại khai báo fault tương ứng.
* Toán tử `expr!` lấy giá trị thành công hoặc `panic` nếu biểu thức chứa fault. Toán tử này dùng được cho cả nullable và error union; trình biên dịch phân biệt dựa trên kiểu tĩnh.
* `catch` xử lý fault tại chỗ và có thể được dùng như một biểu thức:

```text
val player = load() catch {
    IO_ERROR(code, message) -> defaultPlayer()
    INVALID_FORMAT(line) -> reportAndRecover(line)
}
```

Mọi fault trong error union phải được xử lý đầy đủ trong `catch`. Mỗi nhánh phải trả về cùng kiểu với giá trị thành công để toàn bộ biểu thức có một kiểu duy nhất.

Fault được khởi tạo giống struct:

```text
return IO_ERROR(5, "Access denied")
```

Fault chứa field move-only cũng là move-only và tuân theo các quy tắc ownership thông thường.

---

## 7. Quản lý tài nguyên an toàn (Resource Management)

Hỗ trợ từ khóa `defer` để xếp hàng các lệnh dọn dẹp theo thứ tự LIFO (Vào sau ra trước), rất tiện khi gọi hàm C:

```text
fn render() {
    val buffer = glGenBuffers();
    defer glDeleteBuffer(buffer);
    // ... thực hiện render, buffer tự giải phóng khi thoát hàm
}

```

---

## 8. Generics & Tập khả năng (Traits)

Sử dụng cơ chế Đơn hình hóa (Monomorphization) giống Rust/C++, đảm bảo tốc độ tối đa không cần vtable.

### Định nghĩa Trait và Toán tử (Operator Overloading)

```text
trait Comparable {
    fn greaterThan(other: Self): bool;
}

struct Item(value: i32) : Comparable {
    override fn greaterThan(other: Item): bool {
        return self.value > other.value;
    }
}

```

### Hàm Tổng quát & Kiểu Ảo (Meta-types)

Hỗ trợ các nhóm ràng buộc dựng sẵn: `number`, `n8`, `n16`, `n32`, `n64`, `n128`, `integer`, `float`.

```text
// Ràng buộc T phải là một số 32-bit (i32, u32, f32)
fn process<T: n32>(val: T) { ... }

// Ràng buộc T do người dùng định nghĩa
fn sort<T: Comparable>(arr: []T) { ... }

```

---

## 9. Cú pháp hàm & Module

### Kết thúc câu lệnh

Dấu chấm phẩy `;` là bắt buộc sau khai báo biến, `return`, `defer` và expression statement. Block và khai báo hàm không kết thúc bằng dấu chấm phẩy:

```text
fn calculate(): i32 {
    val base: i32 = 10;
    val result = base * 2;
    return result;
}
```

Thiếu `;` là lỗi cú pháp. Trình biên dịch sử dụng dấu này làm ranh giới phục hồi để có thể tiếp tục báo các lỗi phía sau.

### Độ ưu tiên biểu thức

Các toán tử có độ ưu tiên từ thấp đến cao:

| Mức | Nhóm | Toán tử |
| --- | --- | --- |
| 1 | Gán, kết hợp phải | `=`, `+=`, `-=`, `*=`, `/=`, `%=` |
| 2 | Logic OR | `||` |
| 3 | Logic AND | `&&` |
| 4 | So sánh bằng | `==`, `!=` |
| 5 | So sánh thứ tự | `<`, `<=`, `>`, `>=` |
| 6 | Range | `..`, `..<` |
| 7 | Cộng/trừ | `+`, `-` |
| 8 | Nhân/chia/modulo | `*`, `/`, `%` |
| 9 | Cast | `expression as Type` |
| 10 | Prefix | `!`, `-`, `+`, `~` |
| 11 | Postfix | gọi hàm `()`, member `.name`, unwrap `!`, truyền lỗi `?` |

Dấu ngoặc `()` thay đổi thứ tự đánh giá. Các toán tử hai ngôi kết hợp trái, ngoại trừ phép gán kết hợp phải:

```text
val result = 1 + 2 * 3;
val converted = result as f64;
object.get(1).value!;
```

* **Kiểu trả về:** Nếu không khai báo kiểu trả về, hàm mặc định trả về `unit`. Có thể ghi `: unit` tường minh khi cần làm rõ API:

```text
fn abc() {
    print("Hello");
}

fn log(message: string): unit {
    print(message);
}
```

Hàm trả về `unit` không được trả về một giá trị. Biểu thức `()` là giá trị `unit`, nhưng trong thân hàm phải dùng `return;` để thoát sớm; `return ();` là lỗi ngữ nghĩa.

* **Hàm rút gọn (Expression Body):** 

`fn add(a: i32, b: i32) => a + b;`

`fn setA(a: i32, b: i32) => a = b;`

* **Hệ thống Module:**
```text
module math.utils;

import math.utils.Vector;

```


(Cho phép bỏ qua khai báo `module` đối với các tệp kịch bản cục bộ).

`kc0` và compiler bootstrap K tải đệ quy các module được import theo thứ tự
dependency-first rồi phân tích semantic và phát một LLVM module cho toàn bộ
graph. Canonical path được dùng để chỉ tải module dùng chung một lần; diamond
dependency và wildcard `mod.k` đều được hỗ trợ. Compiler bootstrap được build
trực tiếp từ entry `src/kbootstrap/main.k`; PowerShell không còn ghép source.
Loader giữ source-map segment cho từng canonical path, vì vậy lexer, parser,
semantic và import diagnostics đều báo `path:line:column` theo tệp gốc thay vì
offset trong source tổng hợp. Bootstrap lexer phân biệt chuỗi chưa kết thúc và
ký tự không hợp lệ; parser giữ token được mong đợi để báo lỗi như
`expected ';'` thay vì diagnostic chung chung.

Bootstrap CLI yêu cầu đúng bảy đối số sau tên executable. Lỗi arguments,
filesystem hoặc không khởi chạy được `opt`/Clang trả exit code `1`; lỗi source,
semantic, LLVM verification hoặc linker trả exit code `2`. Tool được khởi chạy
thành công nhưng báo IR/link failure vẫn thuộc nhóm diagnostic `2`.
Các nhánh exit `1` phát stderr ổn định (`expected 7 arguments`, `cannot load
input`, `cannot write LLVM output`, `cannot launch opt/clang`). Entry phải có
đuôi `.k`; sáu path output/tool/runtime còn lại không được rỗng. Driver kiểm tra
các contract này trước khi đọc source hoặc chạy tool, phát diagnostic ổn định,
và giải phóng mọi argument buffer đã nhận trước khi thoát sớm.

### Array literal và suy luận kích thước

Array literal dùng cú pháp `[a, b, c]`. Trình biên dịch suy luận kiểu phần tử chung và kích thước từ phép gán:

```text
val values: i8[] = [0, 1, 2, 3];
val empty: i32[] = [];
```

`[]` không tự suy ra được kiểu phần tử, vì vậy `val empty = [];` là lỗi. Khi có kiểu mong đợi, `T[]` được chuyển thành `T[n]` với `n` là số phần tử của literal.

### Kiểm tra ngữ nghĩa

`kc file.k` và `kc --check file.k` đều chạy lexer, parser và semantic analyzer; `--check` in `check succeeded` khi hợp lệ. `--tokens` chỉ dừng sau lexer, còn `--ast` dừng sau parser.

Semantic analyzer thu thập toàn bộ chữ ký hàm trước khi kiểm tra thân hàm, nên forward call và đệ quy hợp lệ. Biến cục bộ chỉ tồn tại từ sau khai báo; cùng scope không được trùng tên, scope lồng nhau được shadow. Gán, đối số và giá trị trả về phải khớp kiểu, ngoại trừ literal có thể thích nghi theo kiểu mong đợi.

### Sinh LLVM IR

Backend dùng LLVM 22.1.8. Trên Windows cần gói development `clang+llvm`, với `LLVM_DIR` trỏ tới `lib/cmake/llvm` trong thư mục giải nén.

```text
kc --emit-llvm program.k -o program.ll
```

Backend hiện hỗ trợ hàm và lời gọi hàm, parameter, `val`/`var`, assignment,
literal và toán tử số, comparison, `if`/`else`, `while`, `return`, raw pointer,
integer casts có kiểm tra, fixed struct, fixed array và slice. `unit` được hạ thành LLVM `void`; `bool`
thành `i1`; raw pointer thành opaque `ptr`; slice thành `{ptr, i64}`. Truy cập
array/slice động sinh bounds check gọi `k_boot_panic`. Backend chạy LLVM verifier
trước khi ghi tệp `.ll`; cấu trúc chưa hỗ trợ được từ chối bằng diagnostic thay
vì sinh IR không hợp lệ.

Native output yêu cầu entry point `fn main(): i32`. Object được sinh bằng LLVM `TargetMachine`; executable được link bằng Clang driver đi kèm LLVM 22.1.8:

```text
kc --emit-obj program.k -o program.obj
kc program.k -o program.exe
```

Khi link executable, `kc` tạo object tạm cạnh file đích. Object tạm được xóa sau khi link thành công và được giữ lại nếu linker thất bại để hỗ trợ chẩn đoán.

### Runtime `print` thử nghiệm

Runtime Windows nhẹ nằm trong `src/lib/std/` và ghi trực tiếp ra stdout bằng `WriteFile`; không dùng `printf`, `sprintf`, iostream hoặc thư viện format. Hiện tại `print` chỉ nhận string literal và `i32`, không tự chèn khoảng trắng hay xuống dòng:

```text
print("value=");
print(42);
```

Kết quả chính xác là `value=42`. Codegen hạ hai dạng này thành ABI nội bộ `k_std_print_bytes(pointer, length)` và `k_std_print_i32(value)`.

### Bootstrap runtime Windows

Runtime bootstrap độc lập với lexer, AST, semantic và LLVM. ABI C tối thiểu cung
cấp `k_boot_alloc`, `k_boot_free`, binary file read/write, current directory,
canonical path, chạy child process, ghi stderr và `k_boot_panic`. Dữ liệu text đi
qua ABI dưới dạng UTF-8 `(pointer, length)`; buffer path trả về do runtime cấp phát,
caller giải phóng bằng `k_boot_free`, và adapter Windows chuyển path/command sang
UTF-16 tại biên OS.
Bounds check của array/slice gọi `k_boot_panic`, ghi `index out of bounds` và
thoát với mã `2`.

### Bootstrap ABI và container chuyên biệt

K khai báo hàm C ABI không có body bằng `extern fn`, ví dụ:

```text
extern fn k_boot_alloc(size: u64): unit*;
extern fn k_boot_free(pointer: unit*);
```

`var` parameter được hạ thành mutable borrow thực sự; thay đổi field qua parameter
được quan sát tại caller. `sizeof(T)` trả `u64` và dùng LLVM target layout.
`src/kbootstrap/containers.k` cung cấp vertical slice chạy được cho `ByteBuffer`,
`TokenList`, `ExprList`, `StringList` và `SymbolTable`. Các container này dùng
raw allocation, tự grow/copy/free và chưa phụ thuộc generic. Chúng đang nằm
chung một source file; việc tách nhỏ thêm chỉ thực hiện khi có nhu cầu cụ thể.
# Bootstrap compiler status

**Module/import self-hosting milestone: complete.** Bootstrap compilation starts
from `src/kbootstrap/main.k`, resolves symbol and wildcard imports in K, loads
dependencies first, de-duplicates canonical paths (including cycles), enforces
the depth-64 boundary, and maps dependency diagnostics back to original files.
Acceptance covers diamond graphs, wildcard `mod.k`, cycles, missing modules,
depth success/failure, and lexer/parser/semantic errors in dependencies across
`kc1` through `kc4`.

**Bootstrap diagnostics/CLI parity milestone: complete.** Lexer, parser,
semantic, import, argument, filesystem, tool-launch, verification, and linker
failures use the established exit-code split. Acceptance requires every stable
CLI failure message exactly once and identically across `kc1` through `kc4`,
alongside exact semantic diagnostic parity.

The bootstrap subset lives in `src/kbootstrap/`; `manifest.txt` is an inventory
and the bootstrap-manifest test requires every listed K source to be reachable
from `main.k` through imports. It currently supports the
dependency-first module loader, lexer, flat AST, Pratt parser, two-pass semantic analysis,
textual LLVM IR, LLVM verification, and Windows x64 linking.

Run:

```powershell
.\scripts\bootstrap.ps1
```

The stages are:

- `kc0`: the C++ compiler built by CMake.
- `kc1`: the `main.k` module graph compiled by `kc0`.
- `kc2`: the same entry graph compiled through `kc1`.
- `kc3`: the entry graph compiled through `kc2`.
- `kc4`: a self-rebuild acceptance stage compiled through `kc3`.

Artifacts are written under `out/bootstrap/stage1` through `stage4`.
The acceptance suite compares valid program behavior, invalid diagnostic
categories/spans and dependency source paths, exercises module graph edge
cases, verifies emitted LLVM IR, and requires `kc3.ll` and `kc4.ll` to have
matching SHA-256 hashes.

The runtime boundary remains a small C++ Windows ABI for allocation, file I/O,
process execution, stderr, panic, and stdout. K directly emits typed LLVM for
the bootstrap subset, including raw pointers, casts, indexing, structs,
demand-driven generic function specializations, and tagged nullable values.
`kc0` is used only to seed `kc1`; later stages do not invoke it. Generic
constraints currently include `any`, `comparable`, `ordered`, `number`,
`integer`, `unsigned`, and `float`; `<T>` means `<T: any>`. The executable
nullable subset supports `T?`, `null`, implicit lifting from `T`, and postfix
`!`.

Bootstrap generic functions and structs accept arbitrary ordered type-parameter
lists. Specialization identity and LLVM symbol names include every concrete
type argument in declaration order; struct construction remains explicit (for
example, `Pair<i32, bool>(40, true)`). Type packs, overload resolution,
ownership/moves, enums, and user-defined traits remain unsupported.
