# Keymap for the WABBLE-60 keyboard.

let { parseKeyMap, .. } = import "kirei/ncl/keymap.ncl" in
let { switch, case, not, is-key-code-pressed, lit, key-press, kc, mod, .. } = import "kirei/ncl/lib.ncl" in

let { to_keycode_segments, qwerty, .. } = import "layouts.ncl" in

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
#
# The WABBLE-60 layout has:
#  a 5x12 'physical' keyboard switch layout,
#  which is represented using a 60-element array.
# mapped to
#  an 8x8 'logical' matrix,
#  which is represented using a 64-element array.

# Constructs a kirei expression from the given keygroup.
let k = fun c => (lit (key-press c)) in

# Alias, constructs a key definition from a keygroup.
let kp = key-press in

# Key definition for no key
let no_key_def = {
    tag = 'none,
    data = {},
} in

# Kirei expression for no key
let no_key_expr = lit no_key_def in

# Record of shifted keycode identifiers, and the
# keycode identifiers they're shifted from.
let shifted_codes = {
  EXLM = "N1",
  AT = "N2",
  HASH = "N3",
  DLR = "N4",
  PERC = "N5",
  CIRC = "N6",
  AMPR = "N7",
  ASTR = "N8",
  LPRN = "N9",
  RPRN = "N0",
  LCBR = "LBRC",
  RCBR = "RBRC",
  TILD = "GRV",
  DQUO = "QUOT",
  COLN = "SCLN",
  QUES = "SLSH",
  PIPE = "BSLS",
  LABK = "COMM",
  RABK = "DOT",
  UNDS = "MINS",
  PLUS = "EQL",
} in

# Keygroups for shifted keycodes
let ks = shifted_codes |> std.record.map_values (fun c => mod 'shift 'left & (std.record.get c kc)) in

# Keygroup for no key
let XXXXXXX = kc.NO_KEY in

# Key definitions for simple modifier keys, which work for both taps and holds
let md = {
    LCTL = kp(kc.LCTL & mod 'ctrl 'left),
    LSFT = kp(kc.LSFT & mod 'shift 'left),
    LALT = kp(kc.LALT & mod 'alt 'left),
    LGUI = kp(kc.LGUI & mod 'gui 'left),
    RCTL = kp(kc.RCTL & mod 'ctrl 'right),
    RSFT = kp(kc.RSFT & mod 'shift 'right),
    RALT = kp(kc.RALT & mod 'alt 'right),
    RGUI = kp(kc.RGUI & mod 'gui 'right),
} in

# Record of layer names to KAx keycodes.
#
# Can consider MO(x) as KAx.
let layers = {
    LOWER = kc.KA0,
    RAISE = kc.KA1,
} in

# Constructs a hold-tap keydef from `t` `h` keydefs.
let tap_hold = fun t h =>
{
    tag = 'hold_tap,
    data = {
        hold_key_def = { value = h },
        tap_key_def = { value = t },
        timeout_ms = 200,
    },
} in

# Record of arrays of kirei expressions for each layer.
let layer_definitions = {
    # Lower (Shifted)
    LOWER = [
        XXXXXXX,   XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,   XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,
        ks.TILD,   ks.EXLM, ks.AT,   ks.HASH, ks.DLR,  ks.PERC,   ks.CIRC, ks.AMPR, ks.ASTR, ks.LPRN, ks.RPRN, ks.PIPE,
        kc.INSERT, kc.F1,   kc.F2,   kc.F3,   kc.F4,   kc.F5,     kc.F6,   ks.UNDS, ks.PLUS, ks.LCBR, ks.RCBR, ks.QUES,
        XXXXXXX,   kc.F7,   kc.F8,   kc.F9,   kc.F10,  kc.F11,    kc.F12,  XXXXXXX, kc.HOME, kc.PGUP, kc.PGDN, kc.END,
        XXXXXXX,   XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,   XXXXXXX, XXXXXXX, kc.LEFT, kc.DOWN, kc.UP,   kc.RIGHT,
    ] |> std.array.map k,
    # Raise:
    RAISE = [
        XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,   XXXXXXX, XXXXXXX,  XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX,
        kc.GRAVE, kc.N1,   kc.N2,   kc.N3,   kc.N4,   kc.N5,     kc.N6,   kc.N7,    kc.N8,    kc.N9,   kc.N0,   kc.BACKSLASH,
        kc.DEL,   XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,   XXXXXXX, kc.MINUS, kc.EQUAL, kc.LBRC, kc.RBRC, kc.SLASH,
        XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,   XXXXXXX, XXXXXXX,  XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX,
        XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,   XXXXXXX, XXXXXXX,  XXXXXXX,  XXXXXXX, XXXXXXX, XXXXXXX,
    ] |> std.array.map k,
} in

# Constructs an array of keydefs given
# a 30-char string for the alphabetical layout.
# (This argument is typically a field from layouts.ncl).
let make_keymap_layer_with = fun alphas_layout =>
    let segments = to_keycode_segments alphas_layout in
    let {
        lhs1 = [a11, a12, a13, a14, a15], rhs1 = [a16, a17, a18, a19, a1A],
        lhs2 = [a21, a22, a23, a24, a25], rhs2 = [a26, a27, a28, a29, a2A],
        lhs3 = [a31, a32, a33, a34, a35], rhs3 = [a36, a37, a38, a39, a3A],
    } = segments in
    let lwr_esc = tap_hold (kp kc.ESCAPE) (kp layers.LOWER) in
    let rse_ent = tap_hold (kp kc.ENTER) (kp layers.RAISE) in
    # There are more concise ways of expressing this,
    # but hopefully this makes the layout clear.
    [
        kp(kc.GRAVE), kp(kc.N1), kp(kc.N2), kp(kc.N3), kp(kc.N4), kp(kc.N5),       kp(kc.N6), kp(kc.N7), kp(kc.N8), kp(kc.N9), kp(kc.N0), kp(kc.DELETE),
        kp(kc.TAB),   kp(a11),   kp(a12),   kp(a13),   kp(a14),   kp(a15),         kp(a16),   kp(a17),   kp(a18),   kp(a19),   kp(a1A),   kp(kc.BACKSPACE),
        kp(kc.ESC),   kp(a21),   kp(a22),   kp(a23),   kp(a24),   kp(a25),         kp(a26),   kp(a27),   kp(a28),   kp(a29),   kp(a2A),   kp(kc.QUOTE),
        md.LSFT,      kp(a31),   kp(a32),   kp(a33),   kp(a34),   kp(a35),         kp(a36),   kp(a37),   kp(a38),   kp(a39),   kp(a3A),   md.RSFT,
        md.LCTL,      md.LGUI,   md.LALT,   kp(kc.TAB),lwr_esc,   kp(kc.SPACE),    kp(kc.BSPC), rse_ent, kp(kc.DEL),md.RALT,   md.RGUI,   md.RCTL,
    ] in

# Transpose record of arrays, to array of records,
#
# e.g.
# nickel> transpose_record_of_arrays { x = ["a", "b"], y = ["c", "d"] }
#
# [ { x = "a", y = "c", }, { x = "b", y = "d", } ]
let transpose_record_of_arrays = fun record_of_arrays =>
    let fields = std.record.fields record_of_arrays in
    if fields == [] then
        []
    else
        let record_value_lengths = std.array.length (std.record.get (std.array.first fields) record_of_arrays) in
        # Construct the array of records
        # by fetching the i-th element of each array.
        std.array.generate
            (fun i =>
                 std.record.from_array
                        (std.array.map
                            (fun f =>
                                let v = std.array.at i (std.record.get f record_of_arrays) in
                                { field = f, value = v })
                            fields))
            record_value_lengths in

# Construct array of kirei switch expressions
# by mixing the base layer keydefs with the layer definitions.
#
# `base_layer_keydefs` is an array of keydefs.
# `fn_layers` is a record where values are array of kirei exprs.
let mix_layers = fun base_layer_keydefs fn_layers =>
    let fn_layers' = transpose_record_of_arrays fn_layers in
    let mk_branches = fun i =>
        (std.array.at i fn_layers')
        |> std.record.map
            (fun layer_name layer_expr =>
                let layer_keycode = std.record.get layer_name layers in
                let is_layer = is-key-code-pressed layer_keycode in
                case is_layer layer_expr)
        |> std.record.values in
    base_layer_keydefs
    |> std.array.map_with_index (fun i kd =>
        switch (mk_branches i) kd) in

# Construct logical matrix of 8 rows and 8 columns (column-wise)
# using the 60 keys of the 5x12 physical layout (row-wise),
#
# Pattern-Matched identifiers is `kRC`
# i.e. k48 is logical row 4 logical col 8
#
# Argument is an array of Kirei expressions.
let logical_matrix_from_physical_matrix = fun
    # physical matrix, iterating through each row
    [
        k11, k61, k32, k82, k53, k24, k74, k45, k16, k66, k37, k87,
        k21, k71, k42, k13, k63, k34, k84, k55, k26, k76, k47, k18,
        k31, k81, k52, k23, k73, k44, k15, k65, k36, k86, k57, k28,
        k41, k12, k62, k33, k83, k54, k25, k75, k46, k17, k67, k38,
        k51, k22, k72, k43, k14, k64, k35, k85, k56, k27, k77, k48,
    ]
=>
    # Last 4 logical rows of logical col 8 aren't connected.
    let k58 = no_key_expr in
    let k68 = no_key_expr in
    let k78 = no_key_expr in
    let k88 = no_key_expr in
    # logical matrix, iterating through each column
    [
        k11, k21, k31, k41, k51, k61, k71, k81,
        k12, k22, k32, k42, k52, k62, k72, k82,
        k13, k23, k33, k43, k53, k63, k73, k83,
        k14, k24, k34, k44, k54, k64, k74, k84,
        k15, k25, k35, k45, k55, k65, k75, k85,
        k16, k26, k36, k46, k56, k66, k76, k86,
        k17, k27, k37, k47, k57, k67, k77, k87,
        k18, k28, k38, k48, k58, k68, k78, k88,
    ] in

mix_layers (make_keymap_layer_with qwerty) layer_definitions
|> logical_matrix_from_physical_matrix
|> parseKeyMap
