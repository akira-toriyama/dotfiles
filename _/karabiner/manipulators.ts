import * as config from "./config.ts";
import * as service from "../_/service.ts";

const chezmoiRoot = service.getChezmoiRoot();

// 左
const button1 = [
  // alt + tab
  {
    "type": "basic",
    "from": {
      "pointing_button": "button2",
      "modifiers": {
        "optional": ["any"],
      },
    },
    to: [
      {
        key_code: "tab",
        modifiers: ["command", "control"],
      },
    ],
    "conditions": [
      {
        "type": "device_if",
        "identifiers": [
          { "vendor_id": config.deviceMap.ist.vendor_id },
        ],
      },
      { "type": "variable_if", "name": "button7_down", "value": 1 },
    ],
  },
] as const;

// 右
const button2 = [
  // alt + tab all
  {
    "type": "basic",
    "from": {
      "pointing_button": "button1",
      "modifiers": {
        "optional": ["any"],
      },
    },
    to: [
      {
        key_code: "tab",
        modifiers: ["option"],
      },
    ],
    "conditions": [
      {
        "type": "device_if",
        "identifiers": [
          { "vendor_id": config.deviceMap.ist.vendor_id },
        ],
      },
      { "type": "variable_if", "name": "button7_down", "value": 1 },
    ],
  },
  {
    "type": "basic",
    "from": {
      "pointing_button": "button2",
      "modifiers": {
        "optional": ["any"],
      },
    },
    "to": [
      { "key_code": "left_option" },
    ],
    "to_if_alone": [
      {
        "pointing_button": "button2",
      },
    ],
    "conditions": [
      {
        "type": "device_if",
        "identifiers": [
          { "vendor_id": config.deviceMap.ist.vendor_id },
        ],
      },
    ],
  },
] as const;

// 右右
const button3 = [
  // デスクトップ一覧
  {
    "type": "basic",
    "from": {
      "pointing_button": "button3",
      "modifiers": {
        "optional": ["any"],
      },
    },
    to: [
      {
        key_code: "spacebar",
        modifiers: ["option", "shift"],
      },
    ],
    "conditions": [
      {
        "type": "device_if",
        "identifiers": [
          { "vendor_id": config.deviceMap.ist.vendor_id },
        ],
      },
      { "type": "variable_if", "name": "button7_down", "value": 1 },
    ],
  },
  {
    "type": "basic",
    "from": {
      "pointing_button": "button3",
      "modifiers": {
        "optional": ["any"],
      },
    },
    "to": [
      { "key_code": "left_control" },
    ],
    "to_if_alone": [
      {
        "pointing_button": "button3",
      },
    ],
    "conditions": [
      {
        "type": "device_if",
        "identifiers": [
          { "vendor_id": config.deviceMap.ist.vendor_id },
        ],
      },
    ],
  },
] as const;

// 親指上
const button7 = [
  {
    "type": "basic",
    "from": {
      "pointing_button": "button7",
      "modifiers": {
        "optional": ["any"],
      },
    },
    "to": [
      { "set_variable": { "name": "button7_down", "value": 1 } },
    ],
    "to_if_alone": [
      {
        "key_code": "escape",
      },
    ],
    "to_after_key_up": [
      { "set_variable": { "name": "button7_down", "value": 0 } },
    ],
    "conditions": [
      { "type": "variable_if", "name": "button7_down", "value": 0 },
      {
        "type": "device_if",
        "identifiers": [
          { "vendor_id": config.deviceMap.ist.vendor_id },
        ],
      },
    ],
  },
] as const;

// 親指下
const button6 = [
  {
    "type": "basic",
    "from": {
      "pointing_button": "button6",
      "modifiers": {
        "optional": ["any"],
      },
    },
    "to_if_alone": [
      {
        shell_command: `osascript -e 'tell application "PopClip" to appear'`,
      },
    ],
    "conditions": [
      {
        "type": "device_if",
        "identifiers": [
          { "vendor_id": config.deviceMap.ist.vendor_id },
        ],
      },
    ],
  },
] as const;

// 進む
const button5 = [
  // 録画 & スクショ
  {
    "type": "basic",
    "from": {
      ...config.mouseMap.button5,
      "modifiers": {
        "optional": ["any"],
      },
    },
    to: [
      {
        "key_code": "5",
        "modifiers": [
          "command",
          "shift",
        ],
      },
    ],
    "conditions": [
      {
        "type": "device_if",
        "identifiers": [
          { "vendor_id": config.deviceMap.ist.vendor_id },
        ],
      },
      { "type": "variable_if", "name": "button7_down", "value": 1 },
    ],
  },
  {
    "type": "basic",
    "from": {
      ...config.mouseMap.button5,
      "modifiers": {
        "optional": ["any"],
      },
    },
    "to_if_alone": [
      {
        "pointing_button": "button5",
      },
    ],
    "conditions": [
      {
        "type": "device_if",
        "identifiers": [
          { "vendor_id": config.deviceMap.ist.vendor_id },
        ],
      },
    ],
  },
] as const;

// 戻る
const button4 = [
  // cmd + bs
  {
    "type": "basic",
    "from": {
      ...config.mouseMap.button4,
      "modifiers": {
        "optional": ["any"],
      },
    },
    to: [
      {
        key_code: "delete_or_backspace",
        modifiers: ["command"],
      },
    ],
    "conditions": [
      {
        "type": "device_if",
        "identifiers": [
          { "vendor_id": config.deviceMap.ist.vendor_id },
        ],
      },
      { "type": "variable_if", "name": "button7_down", "value": 1 },
    ],
  },
  {
    "type": "basic",
    "from": {
      ...config.mouseMap.button4,
      "modifiers": {
        "optional": ["any"],
      },
    },
    "to_if_alone": [
      {
        "pointing_button": "button4",
      },
    ],
    "conditions": [
      {
        "type": "device_if",
        "identifiers": [
          { "vendor_id": config.deviceMap.ist.vendor_id },
        ],
      },
    ],
  },
] as const;

// TODO
// 横スクロール
// ドラッグスクロール
// ジェスチャー
const ist = [
  ...button1,
  ...button2,
  ...button3,
  ...button4,
  ...button5,
  ...button6,
  ...button7,
] as const;

const windowPosition = config.window.map((v) => ({
  from: {
    key_code: config.keyMap.tab.keys[v.key],
    modifiers: {
      mandatory: config.keyMap.tab.modifiers,
    },
  },
  type: "basic",
  to: [
    {
      shell_command: v.move,
    },
  ],
}));

const windowFocus = config.window.map((v) => ({
  from: {
    key_code: config.keyMap.upArrow.keys[v.key],
    modifiers: {
      mandatory: config.keyMap.upArrow.modifiers,
    },
  },
  type: "basic",
  to: [
    {
      shell_command:
        `${config.pathMap.deno} run --allow-run ${chezmoiRoot}/_/karabiner/_/focus.ts ${v.key}`,
    },
  ],
}));

const spaces = [
  /**
   * focus
   */
  ...config.spaces.map(({ keyCode, no }) => ({
    description: `focus space ${no}`,
    from: {
      key_code: config.keyMap.leftArrow.keys[keyCode],
      modifiers: {
        mandatory: config.keyMap.leftArrow.modifiers,
      },
    },
    type: "basic",
    to: [
      {
        shell_command: `${config.pathMap.yabai} -m space --focus ${no}`,
      },
    ],
  })),
  /**
   * send
   */
  ...config.spaces.map(({ keyCode, no }) => ({
    description: `send space ${no}`,
    from: {
      key_code: config.keyMap.downArrow.keys[keyCode],
      modifiers: {
        mandatory: config.keyMap.downArrow.modifiers,
      },
    },
    type: "basic",
    to: [
      {
        shell_command: `${config.pathMap.yabai} -m window --space ${no}`,
      },
    ],
  })),
  /**
   * send & focus
   */
  ...config.spaces.map(({ keyCode, no }) => ({
    description: `focus and send space ${no}`,
    from: {
      key_code: config.keyMap.rightArrow.keys[keyCode],
      modifiers: {
        mandatory: config.keyMap.rightArrow.modifiers,
      },
    },
    type: "basic",
    to: [
      {
        shell_command:
          `${config.pathMap.yabai} -m window --space ${no} && ${config.pathMap.yabai} -m space --focus ${no}`,
      },
    ],
  })),
] as const;

const appSwitching = [
  {
    description: "All spaces",
    from: {
      key_code: config.keyMap.ll.keys.sym2,
      modifiers: {
        mandatory: config.keyMap.ll.modifiers,
      },
    },
    type: "basic",
    to: [
      {
        key_code: "spacebar",
        modifiers: ["option", "shift"],
      },
    ],
  },
  {
    description: "AltTab current スペース",
    from: {
      key_code: config.keyMap.ll.keys.num,
      modifiers: {
        mandatory: config.keyMap.ll.modifiers,
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
    description: "AltTab all スペース",
    from: {
      key_code: config.keyMap.ll.keys.sym1,
      modifiers: {
        mandatory: config.keyMap.ll.modifiers,
      },
    },
    type: "basic",
    to: [
      {
        key_code: "tab",
        modifiers: ["command", "control"],
      },
    ],
  },
] as const;

const tabSwitching = [
  {
    description: "アクティブなタブを左に切り替え",
    from: {
      key_code: config.keyMap.ll.keys.e,
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
      key_code: config.keyMap.ll.keys.e,
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
      key_code: config.keyMap.ll.keys.r,
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
      key_code: config.keyMap.ll.keys.r,
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

const app = [
  {
    description: "ランチャー",
    from: {
      key_code: config.keyMap.ll.key,
      modifiers: {
        mandatory: ["control"],
      },
    },
    type: "basic",
    to: [
      {
        key_code: "japanese_eisuu",
      },
      {
        key_code: "spacebar",
        modifiers: ["option"],
      },
    ],
  },
  {
    description: "辞書.app",
    from: {
      key_code: config.keyMap.ll.key,
      modifiers: {
        mandatory: ["option"],
      },
    },
    type: "basic",
    to: [
      {
        shell_command: `open -a Dictionary`,
      },
      {
        key_code: "japanese_eisuu",
      },
    ],
  },
] as const;

const shortCut = [
  {
    from: {
      key_code: "escape",
    },
    type: "basic",
    to: [
      {
        key_code: "w",
        modifiers: ["command"],
      },
    ],
    conditions: [
      {
        type: "frontmost_application_if",
        bundle_identifiers: [config.appMap.Dictionary],
      },
    ],
  },
] as const;

const mousePointerJump = config.mousePointerJump.map((v) => ({
  from: {
    key_code: config.keyMap.delete.keys[v.key],
    modifiers: {
      mandatory: config.keyMap.delete.modifiers,
    },
  },
  type: "basic",
  to: [
    {
      shell_command:
        `osascript ${chezmoiRoot}/_/bin/mouse-pointer-jump.scpt ${v.x} ${v.y} > /dev/null 2>&1`,
    },
  ],
}));

const soundEffect = [
  {
    "type": "basic",
    "from": {
      "key_code": "lang3",
    },
    "to": [
      {
        shell_command:
          `${config.pathMap.afplay} --volume 0.1 ${chezmoiRoot}/_/soundEffect/to_mouse_layer.mp3 > /dev/null 2>&1`,
      },
    ],
  },
  {
    "type": "basic",
    "from": {
      "key_code": "lang4",
    },
    "to": [
      {
        shell_command:
          `${config.pathMap.afplay} --volume 0.1 ${chezmoiRoot}/_/soundEffect/to_default_layer.mp3 > /dev/null 2>&1`,
      },
    ],
  },
] as const;

const focusSwitching = [
  {
    from: {
      key_code: config.keyMap.ll.keys.f,
      modifiers: {
        mandatory: config.keyMap.ll.modifiers,
      },
    },
    type: "basic",
    to: [
      {
        shell_command: `
${config.pathMap.yabai} -m query --spaces --space |
${config.pathMap.jq} -re ".index" |
${config.pathMap.xargs} -I{} ${config.pathMap.yabai} -m query --windows --space {} |
${config.pathMap.jq} -sre 'add | map(select(."is-minimized"==false)) | sort_by(.display, .frame.y, .frame.x, .id) | . as $array | length as $array_length | index(map(select(."has-focus"==true))) as $has_index | if $array_length - 1 > $has_index then nth($has_index + 1).id else nth(0).id end' |
${config.pathMap.xargs} -I{} ${config.pathMap.yabai} -m window --focus {}
`,
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.ll.keys.d,
      modifiers: {
        mandatory: config.keyMap.ll.modifiers,
      },
    },
    type: "basic",
    to: [
      {
        shell_command: `
  ${config.pathMap.yabai} -m query --spaces --space |
  ${config.pathMap.jq} -re ".index" |
  ${config.pathMap.xargs} -I{} ${config.pathMap.yabai} -m query --windows --space {} |
  ${config.pathMap.jq} -sre 'add | map(select(."is-minimized"==false)) | sort_by(.display, .frame.y, .frame.x, .id) | . as $array | length as $array_length | index(map(select(."has-focus"==true))) as $has_index | if $has_index > 0 then nth($has_index - 1).id else nth($array_length - 1).id end' |
  ${config.pathMap.xargs} -I{} ${config.pathMap.yabai} -m window --focus {}
  `,
      },
    ],
  },
] as const;

export const manipulators = [
  ...ist,
  ...tabSwitching,
  ...spaces,
  ...appSwitching,
  ...windowPosition,
  ...windowFocus,
  ...app,
  ...shortCut,
  ...soundEffect,
  ...focusSwitching,
  ...mousePointerJump,
] as const;
