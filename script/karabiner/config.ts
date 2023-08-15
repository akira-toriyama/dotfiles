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

  //
  del: ["control", "shift", "option", "command"],
  tab: ["control", "shift", "option"],
} as const;

export const appMap = {
  Chrome: "^com\\.google\\.Chrome$",
  VSCode: "^com\\.microsoft\\.VSCode$",
  FSNotes: "^co\\.fluder\\.FSNotes$",
} as const;

export const sizeDownWindow =
  `${pathMap.yabai} -m window --resize right:-4:0 && ${pathMap.yabai} -m window --resize bottom:0:-4 && ${pathMap.yabai} -m window --resize left:4:0 && ${pathMap.yabai} -m window --resize top:0:4`;
