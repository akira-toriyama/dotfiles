import { appMap, keyMap, pathMap } from "./config.ts";

/**
 * 汎用的なショートカット
 */
const shortcut = [
  {
    description: "設定 cmd + ,",
    from: {
      key_code: keyMap.qq,
    },
    type: "basic",
    to: [
      {
        key_code: "comma",
        modifiers: ["command"],
      },
    ],
  },
] as const;

/**
 * アプリ用ショートカット
 */
const appShortcut = [
  {
    description: "markdownと編集モードのトグル",
    from: {
      key_code: keyMap.t,
      modifiers: {
        mandatory: keyMap.tab,
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
        bundle_identifiers: [appMap.FSNotes],
      },
    ],
  },
  {
    description: "コメント",
    from: {
      key_code: keyMap.c,
      modifiers: {
        mandatory: keyMap.tab,
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
        bundle_identifiers: [appMap.VSCode],
      },
    ],
  },
  {
    description: "ターミナルとエディタの移動",
    from: {
      key_code: keyMap.g,
      modifiers: {
        mandatory: keyMap.tab,
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
        bundle_identifiers: [appMap.VSCode],
      },
    ],
  },
] as const;

/**
 * アプリ呼び出し
 */
const callApp = [
  {
    description: "アプリ一覧(現在のスペース",
    from: {
      key_code: keyMap.lr_rl,
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
    description: "アプリ一覧(すべてのスペース",
    from: {
      key_code: keyMap.ll_rr,
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
      key_code: keyMap.ll,
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
    description: "ランチャー",
    from: {
      key_code: keyMap.ll,
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
        key_code: "spacebar",
        modifiers: ["option"],
      },
    ],
  },
] as const;

const changeActiveWindow = [
  {
    description: "アクティブウィンドウの変更 上",
    from: {
      key_code: keyMap.a,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${pathMap.deno} run --allow-run ${pathMap.dotfiles}/script/yabai/focus/up.ts`,
      },
    ],
  },
  {
    description: "アクティブウィンドウの変更 下",
    from: {
      key_code: keyMap.s,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${pathMap.deno} run --allow-run ${pathMap.dotfiles}/script/yabai/focus/down.ts`,
      },
    ],
  },
  {
    description: "アクティブウィンドウの変更 左",
    from: {
      key_code: keyMap.d,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${pathMap.deno} run --allow-run ${pathMap.dotfiles}/script/yabai/focus/left.ts`,
      },
    ],
  },
  {
    description: "アクティブウィンドウの変更 右",
    from: {
      key_code: keyMap.f,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${pathMap.deno} run --allow-run ${pathMap.dotfiles}/script/yabai/focus/right.ts`,
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
      key_code: keyMap.z,
    },
    type: "basic",
    to: [
      {
        shell_command: `${pathMap.yabai} -m window --grid 2:1:0:0:2:1`,
      },
    ],
  },
  {
    description: "画面サイズ変更 (下半分",
    from: {
      key_code: keyMap.x,
    },
    type: "basic",
    to: [
      {
        shell_command: `${pathMap.yabai} -m window --grid 2:1:0:1:2:1`,
      },
    ],
  },
  {
    description: "画面サイズ変更 (左半分",
    from: {
      key_code: keyMap.c,
    },
    type: "basic",
    to: [
      {
        shell_command: `${pathMap.yabai} -m window --grid 1:2:0:0:1:2`,
      },
    ],
  },
  {
    description: "画面サイズ変更 (右半分",
    from: {
      key_code: keyMap.v,
    },
    type: "basic",
    to: [
      {
        shell_command: `${pathMap.yabai} -m window --grid 1:2:1:0:1:2`,
      },
    ],
  },
  {
    description: "画面サイズ変更 (最大",
    from: {
      key_code: keyMap.b,
    },
    type: "basic",
    to: [
      {
        shell_command: `${pathMap.yabai} -m window --grid 1:1:0:0:1:1`,
      },
    ],
  },
  {
    description: "タイリング",
    from: {
      key_code: keyMap.zz,
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${pathMap.yabai} -m config layout bsp && ${pathMap.yabai} -m config layout float`,
      },
    ],
  },
] as const;

const changeActiveTab = [
  {
    description: "タブ左",
    from: {
      key_code: keyMap.e,
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
        bundle_identifiers: [appMap.Chrome],
      },
    ],
  },
  {
    description: "タブ左",
    from: {
      key_code: keyMap.e,
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
        bundle_identifiers: [appMap.VSCode],
      },
    ],
  },
  {
    description: "タブ右",
    from: {
      key_code: keyMap.r,
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
        bundle_identifiers: [appMap.Chrome],
      },
    ],
  },
  {
    description: "タブ右",
    from: {
      key_code: keyMap.r,
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
        bundle_identifiers: [appMap.VSCode],
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
];
