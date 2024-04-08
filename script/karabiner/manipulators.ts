import * as config from "./config.ts";

/**
 * 右クリと合わせて
 */
const rightClickWith = [
  // 右クリでレイヤー切り替え
  {
    "type": "basic",
    "from": {
      "pointing_button": "button2",
      "modifiers": {
        "optional": ["any"],
      },
    },
    "to": [
      { "set_variable": { "name": "button2_down", "value": 1 } },
    ],
    "to_if_alone": [
      {
        "pointing_button": "button2",
      },
    ],
    "to_after_key_up": [
      { "set_variable": { "name": "button2_down", "value": 0 } },
    ],
    "conditions": [
      { "type": "variable_if", "name": "button2_down", "value": 0 },
    ],
  },

  {
    description: "mission control",
    "type": "basic",
    "from": {
      "pointing_button": "button1",
      "modifiers": {
        "optional": ["any"],
      },
    },
    "to": [
      { "key_code": "mission_control" },
    ],
    "conditions": [
      { "type": "variable_if", "name": "button2_down", "value": 1 },
    ],
  },

  {
    description: "スクショ or 録画",
    "type": "basic",
    "from": {
      "pointing_button": "button4",
      "modifiers": {
        "optional": ["any"],
      },
    },
    "to": [
      {
        "key_code": "5",
        "modifiers": [
          "command",
          "shift",
        ],
      },
    ],
    "conditions": [
      { "type": "variable_if", "name": "button2_down", "value": 1 },
    ],
  },

  {
    description: "escape",

    "type": "basic",
    "from": {
      "pointing_button": "button5",
      "modifiers": {
        "optional": ["any"],
      },
    },
    "to": [
      {
        "key_code": "escape",
      },
    ],
    "conditions": [
      { "type": "variable_if", "name": "button2_down", "value": 1 },
    ],
  },
];

/**
 * ドラッグスクロール
 */
const dragScroll = [
  {
    description: "ドラッグスクロール",
    "type": "basic",
    "from": {
      "pointing_button": "button3",
      "modifiers": {
        "optional": ["any"],
      },
    },
    "to": [
      {
        "set_variable": {
          "name": "enable_mouse_motion_to_scroll",
          "value": 1,
        },
        "lazy": true,
      },
    ],
    "to_if_alone": [
      {
        "pointing_button": "button3",
      },
    ],
    "to_after_key_up": [
      {
        "set_variable": {
          "name": "enable_mouse_motion_to_scroll",
          "value": 0,
        },
      },
    ],
  },
  {
    "type": "mouse_motion_to_scroll",
    "from": {
      "modifiers": {
        "optional": ["any"],
      },
    },
    "conditions": [
      {
        "type": "variable_if",
        "name": "enable_mouse_motion_to_scroll",
        "value": 1,
      },
    ],
  },
] as const;

const mouse = [
  ...rightClickWith,
  ...dragScroll,
];

/**
 * 汎用的なショートカット
 */
const shortcut = [
  {
    description: "設定 呼び出し",
    from: {
      key_code: config.keyMap.s,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        key_code: "comma",
        modifiers: ["command"],
      },
    ],
  },
  {
    description: "コメント",
    from: {
      key_code: config.keyMap.c,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        key_code: "slash",
        modifiers: ["command"],
      },
    ],
  },
  {
    description: "新規ウィンドウで、Google Chrome open",
    from: {
      key_code: config.keyMap.g,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        shell_command:
          `open -na "Google Chrome" --args --new-window "" && sleep 0.4 && ${config.window.center}`,
      },
    ],
  },
] as const;

/**
 * アプリ呼び出し
 */
const callApp = [
  // TODO total spaces
  // {
  //   description: "total spaces",
  //   from: {
  //     key_code: config.keyMap.ll,
  //   },
  // },
  {
    description: "ランチャー",
    from: {
      key_code: config.keyMap.ll,
      modifiers: {
        mandatory: ["control"],
      },
    },
    type: "basic",
    to: [
      {
        key_code: "spacebar",
        modifiers: ["option"],
      },
    ],
  },
  {
    description: "alt + tab current スペース",
    from: {
      key_code: config.keyMap.ll,
      modifiers: {
        mandatory: ["command"],
      },
    },
    type: "basic",
    to: [
      {
        key_code: "tab",
        modifiers: ["option"],
      },
    ],
  },
  {
    description: "alt + tab all スペース",
    from: {
      key_code: config.keyMap.ll,
      modifiers: {
        mandatory: ["shift", "command"],
      },
    },
    type: "basic",
    to: [
      {
        key_code: "tab",
        modifiers: ["option", "control"],
      },
    ],
  },

  {
    description: "FSNotes",
    from: {
      key_code: config.keyMap.ll,
      modifiers: {
        mandatory: ["shift"],
      },
    },
    type: "basic",
    to: [
      {
        key_code: "l",
        modifiers: ["control", "option", "shift"],
      },
    ],
  },
  {
    description: "辞書.app",
    from: {
      key_code: config.keyMap.ll,
      modifiers: {
        mandatory: ["option"],
      },
    },
    type: "basic",
    to: [
      {
        "key_code": "japanese_eisuu",
      },
      {
        "shell_command": "open '/System/Applications/Dictionary.app'",
      },
    ],
  },
] as const;

/**
 * アクティブウィンドウ変更
 */
const changeActiveWindow = [
  {
    description: "アクティブウィンドウの変更 上",
    from: {
      key_code: config.keyMap.a,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${config.pathMap.deno} run --allow-run ${config.pathMap.dotfiles}/script/karabiner/_/focus/up.ts`,
      },
    ],
  },
  {
    description: "アクティブウィンドウの変更 下",
    from: {
      key_code: config.keyMap.s,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${config.pathMap.deno} run --allow-run ${config.pathMap.dotfiles}/script/karabiner/_/focus/down.ts`,
      },
    ],
  },
  {
    description: "アクティブウィンドウの変更 左",
    from: {
      key_code: config.keyMap.d,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${config.pathMap.deno} run --allow-run ${config.pathMap.dotfiles}/script/karabiner/_/focus/left.ts`,
      },
    ],
  },
  {
    description: "アクティブウィンドウの変更 右",
    from: {
      key_code: config.keyMap.f,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${config.pathMap.deno} run --allow-run ${config.pathMap.dotfiles}/script/karabiner/_/focus/right.ts`,
      },
    ],
  },
] as const;

/**
 * ウィンドウの位置を変更
 */
const moveWindowPosition = [
  {
    description: "画面サイズ変更 (上半分",
    from: {
      key_code: config.keyMap.z,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${config.pathMap.yabai} -m window --grid 2:1:0:0:2:1 && ${config.window.sizeDown}`,
      },
    ],
  },
  {
    description: "画面サイズ変更 (下半分",
    from: {
      key_code: config.keyMap.x,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${config.pathMap.yabai} -m window --grid 2:1:0:1:2:1 && ${config.window.sizeDown}`,
      },
    ],
  },
  {
    description: "画面サイズ変更 (左半分",
    from: {
      key_code: config.keyMap.c,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${config.pathMap.yabai} -m window --grid 1:2:0:0:1:2 && ${config.window.sizeDown}`,
      },
    ],
  },
  {
    description: "画面サイズ変更 (右半分",
    from: {
      key_code: config.keyMap.v,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${config.pathMap.yabai} -m window --grid 1:2:1:0:1:2 && ${config.window.sizeDown}`,
      },
    ],
  },

  {
    description: "画面サイズ変更 (最大",
    from: {
      key_code: config.keyMap.b,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${config.pathMap.yabai} -m window --grid 1:1:0:0:1:1 && ${config.window.sizeDown}`,
      },
    ],
  },
  {
    description: "ウィンドウタイリング",
    from: {
      key_code: config.keyMap.t,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${config.pathMap.yabai} -m config layout bsp && ${config.pathMap.yabai} -m config layout float`,
      },
    ],
  },
  {
    description: "画面サイズ変更 (中央",
    from: {
      key_code: config.keyMap.g,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${config.pathMap.yabai} -m window --grid 1:5:1:0:3:2 && ${config.window.sizeDown}`,
      },
    ],
  },
] as const;

/**
 * タブ切り替え
 */
const changeActiveTab = [
  {
    description: "アクティブなタブを左に切り替え",
    from: {
      key_code: config.keyMap.e,
    },
    type: "basic",
    to: [
      {
        key_code: "tab",
        modifiers: ["control", "shift"],
      },
    ],
    conditions: [
      {
        type: "frontmost_application_if",
        bundle_identifiers: [config.appMap.Chrome],
      },
    ],
  },
  {
    description: "アクティブなタブを左に切り替え",
    from: {
      key_code: config.keyMap.e,
    },
    type: "basic",
    to: [
      {
        key_code: "open_bracket",
        modifiers: ["command", "shift"],
      },
    ],
    conditions: [
      {
        type: "frontmost_application_if",
        bundle_identifiers: [config.appMap.VSCode],
      },
    ],
  },
  {
    description: "アクティブなタブを右に切り替え",
    from: {
      key_code: config.keyMap.r,
    },
    type: "basic",
    to: [
      {
        key_code: "tab",
        modifiers: ["control"],
      },
    ],
    conditions: [
      {
        type: "frontmost_application_if",
        bundle_identifiers: [config.appMap.Chrome],
      },
    ],
  },
  {
    description: "アクティブなタブを右に切り替え",
    from: {
      key_code: config.keyMap.r,
    },
    type: "basic",
    to: [
      {
        key_code: "close_bracket",
        modifiers: ["command", "shift"],
      },
    ],
    conditions: [
      {
        type: "frontmost_application_if",
        bundle_identifiers: [config.appMap.VSCode],
      },
    ],
  },
] as const;

export const manipulators = [
  ...changeActiveWindow,
  ...moveWindowPosition,
  ...changeActiveTab,
  ...callApp,
  ...shortcut,
  ...mouse,
];
