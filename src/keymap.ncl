let { parseKeyMap, .. } = import "kirei/ncl/keymap.ncl" in
let { switch, case, not, is-key-pressed, lit, key-press, kc, mod-weak-anti, .. } = import "kirei/ncl/lib.ncl" in

let { to_keycode_segments, qwerty, .. } = import "layouts.ncl" in

let k = fun c => (lit (key-press c)) in

# Keymap for the WABBLE-60 keyboard.
#
# The WABBLE-60 layout has:
#  a 5x12 'physical' keyboard switch layout
# mapped to
#  an 8x8 'logical' matrix.

# Syntactic helper for constructing an array of 60 keys.
#
# Argument identifiers `kRC` for physical keyboard row R, column C
let make_array60 = fun
    k11 k12 k13 k14 k15 k16 k17 k18 k19 k1A k1B k1C
    k21 k22 k23 k24 k25 k26 k27 k28 k29 k2A k2B k2C
    k31 k32 k33 k34 k35 k36 k37 k38 k39 k3A k3B k3C
    k41 k42 k43 k44 k45 k46 k47 k48 k49 k4A k4B k4C
    k51 k52 k53 k54 k55 k56 k57 k58 k59 k5A k5B k5C
=>
[
    k11, k12, k13, k14, k15, k16, k17, k18, k19, k1A, k1B, k1C,
    k21, k22, k23, k24, k25, k26, k27, k28, k29, k2A, k2B, k2C,
    k31, k32, k33, k34, k35, k36, k37, k38, k39, k3A, k3B, k3C,
    k41, k42, k43, k44, k45, k46, k47, k48, k49, k4A, k4B, k4C,
    k51, k52, k53, k54, k55, k56, k57, k58, k59, k5A, k5B, k5C,
] in

let make_keymap_with = fun alphas_layout =>
    let segments = to_keycode_segments alphas_layout in
    let { lhs1, lhs2, lhs3, .. } = segments in
    let { rhs1, rhs2, rhs3, .. } = segments in
    [kc.GRAVE, kc.N1, kc.N2, kc.N3, kc.N4, kc.N5, kc.N6, kc.N7, kc.N8, kc.N9, kc.N0, kc.DELETE] @
    [kc.TAB]        @ lhs1 @ rhs1 @ [kc.BACKSPACE] @
    [kc.ESCAPE]     @ lhs2 @ rhs2 @ [kc.QUOTE] @
    [kc.LEFT_SHIFT] @ lhs3 @ rhs3 @ [kc.RIGHT_SHIFT] @
    [kc.LEFT_CTRL, kc.LEFT_GUI, kc.LEFT_ALT, kc.TAB, kc.ESCAPE, kc.SPACE, kc.BACKSPACE, kc.ENTER, kc.DELETE, kc.RIGHT_ALT, kc.RIGHT_GUI, kc.RIGHT_CTRL]
in

# Helper function for `parseKeyMap`,
#  which takes in the 60 keys of the 5x12 physical layout,
#  and returns an array as `parseKeyMap` expects.
#
# Pattern-Matched identifiers is `kRC`
# i.e. k48 is logical row 4 logical col 8
let to_logical_keymap = fun
    input @ [
        k11, k61, k32, k82, k53, k24, k74, k45, k16, k66, k37, k87,
        k21, k71, k42, k13, k63, k34, k84, k55, k26, k76, k47, k18,
        k31, k81, k52, k23, k73, k44, k15, k65, k36, k86, k57, k28,
        k41, k12, k62, k33, k83, k54, k25, k75, k46, k17, k67, k38,
        k51, k22, k72, k43, k14, k64, k35, k85, k56, k27, k77, k48,
    ]
=>
    # Last 4 logical rows of logical col 8 aren't connected.
    let k58 = kc.NO_KEY in
    let k68 = kc.NO_KEY in
    let k78 = kc.NO_KEY in
    let k88 = kc.NO_KEY in
    [
        k(k11), k(k21), k(k31), k(k41), k(k51), k(k61), k(k71), k(k81),
        k(k12), k(k22), k(k32), k(k42), k(k52), k(k62), k(k72), k(k82),
        k(k13), k(k23), k(k33), k(k43), k(k53), k(k63), k(k73), k(k83),
        k(k14), k(k24), k(k34), k(k44), k(k54), k(k64), k(k74), k(k84),
        k(k15), k(k25), k(k35), k(k45), k(k55), k(k65), k(k75), k(k85),
        k(k16), k(k26), k(k36), k(k46), k(k56), k(k66), k(k76), k(k86),
        k(k17), k(k27), k(k37), k(k47), k(k57), k(k67), k(k77), k(k87),
        k(k18), k(k28), k(k38), k(k48), k(k58), k(k68), k(k78), k(k88),
    ] in

make_keymap_with qwerty
|> to_logical_keymap |> parseKeyMap
