export const pathMap = {
  yabai: "/opt/homebrew/bin/yabai",
  node: "/Users/tommy/.asdf/shims/node",
  dotfiles: "/Users/tommy/dotfiles",
  deno: "/Users/tommy/.asdf/shims/deno",
  jq: "/opt/homebrew/bin/jq",
  xargs: "/usr/bin/xargs",
} as const;

export const keyMap = {
  q: "keypad_1",
  w: "keypad_2",
  e: "keypad_3",
  r: "keypad_4",
  t: "keypad_5",
  a: "keypad_6",
  s: "keypad_7",
  d: "keypad_8",
  f: "keypad_9",
  g: "keypad_plus",
  z: "keypad_equal_sign",
  x: "keypad_period",
  c: "keypad_hyphen",
  v: "keypad_slash",
  b: "keypad_asterisk",

  //
  qq: "non_us_backslash", // qの左
  aa: "insert", // aの左
  zz: "keypad_enter", // zの左
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

export const spaces = [
  keyMap.q,
  keyMap.w,
  keyMap.e,
  keyMap.r,
  keyMap.t,
  keyMap.a,
  keyMap.s,
  keyMap.d,
  keyMap.f,
  keyMap.g,
  keyMap.z,
  keyMap.x,
  keyMap.c,
  keyMap.v,
  keyMap.b,
] as const;

export const window = [
  {
    key: "q",
    move: `${pathMap.yabai} -m window --grid 2:3:0:0:2:1`,
    "frame": {
      "x": 6.0000,
      "y": 6.0000,
      "w": 3401.0000,
      "h": 1071.0000,
    },
  },
  {
    key: "w",
    move: `${pathMap.yabai} -m window --grid 2:3:0:0:1:1`,
    "frame": {
      "x": 6.0000,
      "y": 6.0000,
      "w": 1701.0000,
      "h": 1071.0000,
    },
  },
  {
    key: "e",
    move: `${pathMap.yabai} -m window --grid 2:3:1:0:1:1`,
    "frame": {
      "x": 1710.0000,
      "y": 6.0000,
      "w": 1699.0000,
      "h": 1071.0000,
    },
  },
  {
    key: "r",
    move: `${pathMap.yabai} -m window --grid 2:3:2:0:1:1`,
    "frame": {
      "x": 3413.0000,
      "y": 6.0000,
      "w": 1701.0000,
      "h": 1071.0000,
    },
  },
  {
    key: "t",
    move: `${pathMap.yabai} -m window --grid 2:3:1:0:2:1`,
    "frame": {
      "x": 1712.0000,
      "y": 6.0000,
      "w": 3401.0000,
      "h": 1071.0000,
    },
  },
  {
    key: "a",
    move: `${pathMap.yabai} -m window --grid 1:3:0:0:2:1`,
    "frame": {
      "x": 6.0000,
      "y": 6.0000,
      "w": 3401.0000,
      "h": 2148.0000,
    },
  },
  {
    key: "s",
    move: `${pathMap.yabai} -m window --grid 1:3:0:0:1:1`,
    "frame": {
      "x": 6.0000,
      "y": 6.0000,
      "w": 1701.0000,
      "h": 2148.0000,
    },
  },
  {
    key: "d",
    move: `${pathMap.yabai} -m window --grid 1:3:1:0:1:1`,
    "frame": {
      "x": 1710.0000,
      "y": 6.0000,
      "w": 1699.0000,
      "h": 2148.0000,
    },
  },
  {
    key: "f",
    move: `${pathMap.yabai} -m window --grid 1:3:2:0:1:1`,
    "frame": {
      "x": 3413.0000,
      "y": 6.0000,
      "w": 1701.0000,
      "h": 2148.0000,
    },
  },
  {
    key: "g",
    move: `${pathMap.yabai} -m window --grid 1:3:1:0:2:1`,
    "frame": {
      "x": 1712.0000,
      "y": 6.0000,
      "w": 3401.0000,
      "h": 2148.0000,
    },
  },
  {
    key: "z",
    move: `${pathMap.yabai} -m window --grid 2:3:0:1:2:1`,
    "frame": {
      "x": 6.0000,
      "y": 1083.0000,
      "w": 3401.0000,
      "h": 1071.0000,
    },
  },
  {
    key: "x",
    move: `${pathMap.yabai} -m window --grid 2:3:0:1:1:1`,
    "frame": {
      "x": 6.0000,
      "y": 1083.0000,
      "w": 1701.0000,
      "h": 1071.0000,
    },
  },
  {
    key: "c",
    move: `${pathMap.yabai} -m window --grid 2:3:1:1:1:1`,
    "frame": {
      "x": 1710.0000,
      "y": 1083.0000,
      "w": 1699.0000,
      "h": 1071.0000,
    },
  },
  {
    key: "v",
    move: `${pathMap.yabai} -m window --grid 2:3:2:1:1:1`,
    "frame": {
      "x": 3413.0000,
      "y": 1083.0000,
      "w": 1701.0000,
      "h": 1071.0000,
    },
  },
  {
    key: "b",
    move: `${pathMap.yabai} -m window --grid 2:3:1:1:2:1`,
    "frame": {
      "x": 1712.0000,
      "y": 1083.0000,
      "w": 3401.0000,
      "h": 1071.0000,
    },
  },
  {
    key: "aa",
    move: `${pathMap.yabai} -m window --grid 1:1:0:0:1:1`,
    "frame": {
      "x": 6.0000,
      "y": 6.0000,
      "w": 5108.0000,
      "h": 2148.0000,
    },
  },
  {
    key: "zz",
    move: `${pathMap.yabai} -m window --grid 30:30:4:1:22:28`,
    "frame": {
      "x": 691.0000,
      "y": 84.0000,
      "w": 3737.0000,
      "h": 1994.0000,
    },
  },
] as const;
