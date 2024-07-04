# Keymap for the PyKey40 Lite keyboard.

let { parseKeyMap, .. } = import "kirei/ncl/keymap.ncl" in
let { switch, case, and, is-key-code-pressed, lit, key-press, key-toggle, kc, mod, .. } = import "kirei/ncl/lib.ncl" in

# Impl. Note: Concepts to be familiar with:
# Most of these are types which are described in `kirei/ncl/keymap.ncl`.
# - Keycode - a simple code for a key on a keyboard.
# - KeyGroup - a record with keycodes and modifiers.
#   e.g. `kc.A` is a keygroup.
#   e.g. `mod 'ctrl 'left & kc.A` is a keygroup.
# - Key Definition ("Keydef") - typically a key-press of a keygroup; can also be a key-toggle or hold-tap.
#   e.g. `key-press kc.A` is a keydef.
# - Kirei Expression - Kirei's keymap logic, which allows for declaring sophisticated keymap behaviour.
#   e.g. `lit (key-press kc.A)` is a kirei expression for a literal key A.

# Build binary with:
#   zig build -Dplatform=rp2040
# the uf2 can be flashed using zig-out/firmware/kirei-rp2040.uf2

# Constructs a kirei expression from the given keycode
let k = fun c => (lit (key-press c)) in

# Key definition for no key
let no_key_def = {
    tag = 'none,
    data = {},
} in

# Kirei expression for no key
let no_key_expr = lit no_key_def in

# Syntactic helper for constructing an array of 42 keys.
#
# Argument identifiers `kRC` for physical keyboard row R, column C
let make_array42 = fun
    k11 k12 k13 k14 k15         k18 k19 k1A k1B k1C
    k21 k22 k23 k24 k25         k28 k29 k2A k2B k2C
    k31 k32 k33 k34 k35         k38 k39 k3A k3B k3C
    k41 k42 k43 k44 k45 k46 k47 k48 k49 k4A k4B k4C
=>
[
    k11, k12, k13, k14, k15,           k18, k19, k1A, k1B, k1C,
    k21, k22, k23, k24, k25,           k28, k29, k2A, k2B, k2C,
    k31, k32, k33, k34, k35,           k38, k39, k3A, k3B, k3C,
    k41, k42, k43, k44, k45, k46, k47, k48, k49, k4A, k4B, k4C,
] in

# nickel> transpose_array 2 3 [1, 2, 3, 7, 8, 9]
#
# [ 1, 7, 2, 8, 3, 9 ]
let transpose_array = fun rows cols arr =>
    std.array.generate (fun idx =>
      let r = std.number.floor (idx % rows) in
      let c = std.number.floor (idx / rows) in
      std.array.at (r * cols + c) arr
    )
    (rows * cols) in

# Helper function for `parseKeyMap`,
#  which takes in the 47 keycodes for the planck_mit physical layout,
#  and returns an array of kirei expressions as `parseKeyMap` expects.
#
# Pattern-Matched identifiers is `kRC`
# i.e. k48 is logical row 4 logical col 8
let pico42 = fun
    input @ [
        k11, k12, k13, k14, k15,           k18, k19, k1A, k1B, k1C,
        k21, k22, k23, k24, k25,           k28, k29, k2A, k2B, k2C,
        k31, k32, k33, k34, k35,           k38, k39, k3A, k3B, k3C,
        k41, k42, k43, k44, k45, k46, k47, k48, k49, k4A, k4B, k4C,
    ]
=>
    # PyKey40 Lite doesn't have a key at (4, 7)
    let XXXX = no_key_expr in
    let row_wise_matrix = [
        k(k11), k(k12), k(k13), k(k14), k(k15), XXXX,   XXXX,   k(k18), k(k19), k(k1A), k(k1B), k(k1C),
        k(k21), k(k22), k(k23), k(k24), k(k25), XXXX,   XXXX,   k(k28), k(k29), k(k2A), k(k2B), k(k2C),
        k(k31), k(k32), k(k33), k(k34), k(k35), XXXX,   XXXX,   k(k38), k(k39), k(k3A), k(k3B), k(k3C),
        k(k41), k(k42), k(k43), k(k44), k(k45), k(k46), k(k47), k(k48), k(k49), k(k4A), k(k4B), k(k4C),
    ] in
    let rows = 4 in
    let cols = 12 in
    # Parse-keymap takes in keys column-by-column
    transpose_array rows cols row_wise_matrix in

make_array42
    kc.Q  kc.W  kc.E  kc.R  kc.T          kc.Y  kc.U  kc.I     kc.O   kc.P
    kc.A  kc.S  kc.D  kc.F  kc.G          kc.H  kc.J  kc.K     kc.L   kc.SEMICOLON
    kc.Z  kc.X  kc.C  kc.V  kc.B          kc.N  kc.M  kc.COMMA kc.DOT kc.SLASH
    kc.LEFT_CTRL  kc.LEFT_GUI kc.LEFT_ALT kc.TAB kc.ESCAPE kc.SPACE kc.BACKSPACE kc.ENTER kc.DELETE kc.RIGHT_ALT kc.RIGHT_GUI kc.RIGHT_CTRL
|> pico42 |> parseKeyMap
