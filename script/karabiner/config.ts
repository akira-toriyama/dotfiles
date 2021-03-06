export const pathMap = {
  yabai: "/usr/local/bin/yabai",
  node: "/Users/tommy/.asdf/shims/node",
  dotfiles: "/Users/tommy/dotfiles",
  deno: "/Users/tommy/.asdf/shims/deno",
} as const;

export const keyMap = {
  qq: "non_us_backslash", // qの左
  q: "keypad_1",
  w: "keypad_2",
  e: "keypad_3",
  r: "keypad_4",
  t: "keypad_5",
  aa: "keypad_num_lock", // aの左
  a: "keypad_6",
  s: "keypad_7",
  d: "keypad_8",
  f: "keypad_9",
  g: "keypad_plus",
  zz: "keypad_enter", // zの左
  z: "keypad_equal_sign",
  x: "keypad_period",
  c: "keypad_hyphen",
  v: "keypad_slash",
  b: "keypad_asterisk",
  ll: "keypad_0", // lの右

  // 親指
  ll_rr: "f19",
  lr_rl: "f18",
  ll_rl: "f17",
  lr_rr: "f16",

  //
  del: ["control", "shift", "option", "command"],
  tab: ["control", "shift", "option"],
} as const;

export const appMap = {
  Chrome: "^com\\.google\\.Chrome$",
  VSCode: "^com\\.microsoft\\.VSCode$",
  FSNotes: "^co\\.fluder\\.FSNotes$",
} as const;
