export const pathMap = {
  yabai: "/opt/homebrew/bin/yabai",
  node: "/Users/tommy/.asdf/shims/node",
  deno: "/Users/tommy/.asdf/shims/deno",
  jq: "/opt/homebrew/bin/jq",
  xargs: "/usr/bin/xargs",
  afplay: "/usr/bin/afplay",
} as const;

export const appMap = {
  Chrome: "^com\\.google\\.Chrome$",
  VSCode: "^com\\.microsoft\\.VSCode$",
  FSNotes: "^co\\.fluder\\.FSNotes$",
  Dictionary: "^com\\.apple\\.Dictionary",
} as const;

const _keyMap = {
  q: "f13",
  w: "f14",
  e: "f15",
  r: "f16",
  t: "f17",
  a: "f18",
  s: "f19",
  d: "f20",
  f: "f21",
  g: "f22",
  z: "f23",
  x: "f24",
  c: "non_us_pound",
  v: "print_screen",
  b: "pause",
  ll: "insert",
  lr: "keypad_enter",
  qq: "lang5",
  aa: "non_us_backslash",
  zz: "application",
  num: "lang6",
  sym1: "lang7",
  sym2: "lang8",
} as const;

export const keyMap = {
  tab: {
    modifiers: ["right_option", "right_shift"],
    keys: _keyMap,
  },
  delete: {
    modifiers: ["right_command", "right_shift"],
    keys: _keyMap,
  },
  leftArrow: {
    modifiers: ["right_option", "right_control"],
    keys: _keyMap,
  },
  downArrow: {
    modifiers: ["right_command", "right_option"],
    keys: _keyMap,
  },
  rightArrow: {
    modifiers: ["right_command", "right_control"],
    keys: _keyMap,
  },
  upArrow: {
    modifiers: ["right_shift", "right_control"],
    keys: _keyMap,
  },
  ll: {
    modifiers: [],
    key: "keypad_0",
    keys: {
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
      ll: "international7",
      lr: "international8",
      aa: "international1",
      qq: "international3",
      zz: "japanese_pc_katakana",
      num: "japanese_pc_xfer",
      sym1: "japanese_pc_nfer",
      sym2: "international6",
    },
  },
  oLl: {
    modifiers: [
      "right_shift",
      "right_control",
      "right_command",
      "right_option",
    ],
    keys: {
      s: "f24",
      d: "f23",
      f: "f22",
      e: "f21",
      leftArrow: "f20",
      downArrow: "f17",
      rightArrow: "f19",
      upArrow: "f18",
    },
  },
  layer: {
    modifiers: [
      "right_shift",
      "right_control",
      "right_command",
      "right_option",
    ],
    keys: {
      num: "lang5",
      sym1: "lang6",
      sym2: "lang7",
    },
  },
  qq: {
    modifiers: [
      "right_shift",
      "right_control",
      "right_command",
      "right_option",
    ],
    key: "lang8",
  },
  pp: {
    modifiers: [
      "right_shift",
      "right_control",
      "right_command",
      "right_option",
    ],
    key: "lang9",
  },
} as const;

const _spaces = [
  "q",
  "w",
  "e",
  "r",
  "t",
  "a",
  "s",
  "d",
  "f",
  "g",
  "z",
  "x",
  "c",
  "v",
  "b",
] as const;

export const spaces = _spaces.map((v, k) => ({
  keyCode: v,
  no: k + 1,
}));

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
    key: "ll",
    move: `${pathMap.yabai} -m window --grid 1:2:0:0:1:1`,
    "frame": {
      "x": 6.0000,
      "y": 6.0000,
      "w": 2551.0000,
      "h": 2148.0000,
    },
  },
  {
    key: "lr",
    move: `${pathMap.yabai} -m window --grid 1:2:2:0:1:1`,
    "frame": {
      "x": 2563.0000,
      "y": 6.0000,
      "w": 2551.0000,
      "h": 2148.0000,
    },
  },
  {
    key: "aa",
    move: `${pathMap.yabai} -m window --grid 30:30:4:1:22:28`,
    "frame": {
      "x": 691.0000,
      "y": 84.0000,
      "w": 3737.0000,
      "h": 1994.0000,
    },
  },
  {
    key: "zz",
    move: `${pathMap.yabai} -m window --grid 1:1:0:0:1:1`,
    "frame": {
      "x": 6.0000,
      "y": 6.0000,
      "w": 5108.0000,
      "h": 2148.0000,
    },
  },
] as const;

const x = 5120;
const y = 2160;
export const mousePointerJump = [
  {
    key: "q",
    x: x * 0,
    y: 0,
  },
  {
    key: "w",
    x: x * 0.25,
    y: 0,
  },
  {
    key: "e",
    x: x * 0.5,
    y: 0,
  },
  {
    key: "r",
    x: x * 0.75,
    y: 0,
  },
  {
    key: "t",
    x: x * 1,
    y: 0,
  },

  {
    key: "a",
    x: x * 0,
    y: y / 2,
  },
  {
    key: "s",
    x: x * 0.25,
    y: y / 2,
  },
  {
    key: "d",
    x: x * 0.5,
    y: y / 2,
  },
  {
    key: "f",
    x: x * 0.75,
    y: y / 2,
  },
  {
    key: "g",
    x: x * 1,
    y: y / 2,
  },

  {
    key: "z",
    x: x * 0,
    y: y,
  },
  {
    key: "x",
    x: x * 0.25,
    y: y,
  },
  {
    key: "c",
    x: x * 0.5,
    y: y,
  },
  {
    key: "v",
    x: x * 0.75,
    y: y,
  },
  {
    key: "b",
    x: x * 1,
    y: y,
  },
] as const;
