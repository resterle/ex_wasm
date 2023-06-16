(module
  (import "console" "log" (func $log (param i32)))
  (import "foo" "bar" (func $foo (param i32)))
  (import "foo" "baz" (global $gi i32))
  (global $ga (export "ga") i32 (i32.const 5))
  (func $main
    (local $var i32) ;; create a local variable named $var
    (local.set $var (i32.const 10)) ;; set $var to 10
    local.get $var ;; load $var onto the stack
    call $log ;; log the result
    call $answer
    call $log
  )
  (func $add (export "add") (param i32) (result i32)
  	(local.get 0)
    (local.get 0)
    i32.add
  )
  (func $answer (export "answer") (result i32)
    i32.const 42
  )
  (start $main)
  (global $gb (export "gb") i32 (i32.const 6))
)