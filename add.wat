(module
  (import "host" "log" (func $log (param i32)))
  (import "host" "var" (global $var i32))
  (global $var2 i32 (i32.const 815))
  (global $const (mut i32) (i32.const 815))
  (global $glob (mut i32) (global.get $var))
  (func $add (param $lhs i32) (param $rhs i32) (result i32)
    (local $var i32)
    local.get $lhs
    local.get $rhs
    i32.add
    local.tee $var
    global.set $glob
    global.get $glob)
  (func $main
    global.get $var
    i32.const 40
    call $add
    call $log
  )
  (start $main)
  (export "add" (func $add))
)
