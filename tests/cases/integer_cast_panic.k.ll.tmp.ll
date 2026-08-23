target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

declare void @k_std_print_i32(i32)

declare void @k_std_print_bytes(ptr, i64)

declare void @k_boot_panic(ptr, i64)
@.kpanic_integer = private unnamed_addr constant [26 x i8] c"integer cast out of range\00"
@.kpanic_float = private unnamed_addr constant [24 x i8] c"float cast out of range\00"

declare ptr @k_std_alloc(i64)
declare void @k_std_free(ptr)



define i8 @narrow(i32 %arg.value) {
entry:
  
  %local.10 = alloca i32
  store i32 %arg.value, ptr %local.10
  %0 = load i32, ptr %local.10
  %1 = trunc i32 %0 to i8
  %2 = zext i8 %1 to i32
  %3 = icmp eq i32 %0, %2
  br i1 %3, label %b0, label %b1
b1:
  %4 = getelementptr inbounds [26 x i8], ptr @.kpanic_integer, i64 0, i64 0
  call void @k_boot_panic(ptr %4, i64 25)
  unreachable
b0:
  ret i8 %1

}
define i32 @main() {
entry:
  
  %0 = call i8 @narrow(i32 256)
  %1 = zext i8 %0 to i32
  ret i32 %1

}
