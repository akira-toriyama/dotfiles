import * as config from "./config.ts";

/**
 * ドラッグスクロール
 */
const _dragScroll = [
  {
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

/**
 * https://karabiner-elements.pqrs.org/docs/manual/configuration/configure-devices/
 */
const mouse = [
  ..._dragScroll,
] as const;

/**
 * 汎用的なショートカット
 */
const shortcut = [
  // {
  //   description: "設定 cmd + ,",
  //   from: {
  //     key_code: config.keyMap.qq,
  //   },
  //   type: "basic",
  //   to: [
  //     {
  //       key_code: "comma",
  //       modifiers: ["command"],
  //     },
  //   ],
  // },
] as const;

/**
 * アプリ用ショートカット
 */
const appShortcut = [
  {
    description: "markdownと編集モードのトグル",
    from: {
      key_code: config.keyMap.t,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        key_code: "grave_accent_and_tilde",
        modifiers: ["command"],
      },
    ],
    conditions: [
      {
        type: "frontmost_application_if",
        bundle_identifiers: [config.appMap.FSNotes],
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
    conditions: [
      {
        type: "frontmost_application_if",
        bundle_identifiers: [config.appMap.VSCode],
      },
    ],
  },
  {
    description: "ターミナルとエディタの移動",
    from: {
      key_code: config.keyMap.g,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        key_code: "i",
        modifiers: ["command", "control"],
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

/**
 * アプリ呼び出し
 */
const callApp = [
  {
    description: "alt + tab",
    from: {
      key_code: config.keyMap.ll,
      modifiers: {
        mandatory: ["shift", "control"],
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
    description: "alt + tab 2",
    from: {
      key_code: config.keyMap.ll,
      modifiers: {
        mandatory: ["option", "command"],
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
        mandatory: ["option", "control"],
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
        mandatory: ["command"],
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
        "key_code": "japanese_eisuu",
      },
      {
        key_code: "spacebar",
        modifiers: ["option"],
      },
    ],
  },
  {
    description: "Shortcat",
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
        key_code: "keypad_0",
        modifiers: ["option"],
      },
    ],
  },

  {
    description: "翻訳",
    from: {
      key_code: config.keyMap.ll,
      modifiers: {
        mandatory: ["shift"],
      },
    },
    type: "basic",
    to: [
      {
        "key_code": "japanese_eisuu",
      },
      {
        "shell_command": "open '/Applications/DeepL.app'",
      },
    ],
  },
] as const;

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
          `${config.pathMap.deno} run --allow-run ${config.pathMap.dotfiles}/script/karabiner/yabai/focus/up.ts`,
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
          `${config.pathMap.deno} run --allow-run ${config.pathMap.dotfiles}/script/karabiner/yabai/focus/down.ts`,
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
          `${config.pathMap.deno} run --allow-run ${config.pathMap.dotfiles}/script/karabiner/yabai/focus/left.ts`,
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
          `${config.pathMap.deno} run --allow-run ${config.pathMap.dotfiles}/script/karabiner/yabai/focus/right.ts`,
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
          `${config.pathMap.yabai} -m window --grid 2:1:0:0:2:1 && ${config.sizeDownWindow}`,
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
          `${config.pathMap.yabai} -m window --grid 2:1:0:1:2:1 && ${config.sizeDownWindow}`,
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
          `${config.pathMap.yabai} -m window --grid 1:2:0:0:1:2 && ${config.sizeDownWindow}`,
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
          `${config.pathMap.yabai} -m window --grid 1:2:1:0:1:2 && ${config.sizeDownWindow}`,
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
          `${config.pathMap.yabai} -m window --grid 1:1:0:0:1:1 && ${config.sizeDownWindow}`,
      },
    ],
  },
  {
    description: "タイリング",
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
          `${config.pathMap.yabai} -m window --grid 1:5:1:0:3:2 && ${config.sizeDownWindow}`,
      },
    ],
  },
] as const;

const changeActiveTab = [
  {
    description: "タブ左",
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
    description: "タブ左",
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
    description: "タブ右",
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
    description: "タブ右",
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
  ...appShortcut,
  ...shortcut,
  ...mouse,
];
