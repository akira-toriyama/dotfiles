import * as config from "./config.ts";
import * as service from "../_/service.ts";

const chezmoiRoot = service.getChezmoiRoot();

const button2 = [
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
    description: "alt",
    "type": "basic",
    "from": {
      "pointing_button": "button1",
      "modifiers": {
        "optional": ["any"],
      },
    },
    "to": [
      {
        "pointing_button": "button1",
        "modifiers": [
          "left_option",
        ],
      },
    ],
    "conditions": [
      { "type": "variable_if", "name": "button2_down", "value": 1 },
    ],
  },
] as const;

const button3 = [
  {
    "type": "basic",
    "from": {
      "pointing_button": "button3",
      "modifiers": {
        "optional": ["any"],
      },
    },
    "to": [
      { "set_variable": { "name": "button3_down", "value": 1 } },
    ],
    "to_if_alone": [
      {
        "pointing_button": "button3",
      },
    ],
    "to_after_key_up": [
      { "set_variable": { "name": "button3_down", "value": 0 } },
    ],
    "conditions": [
      { "type": "variable_if", "name": "button3_down", "value": 0 },
    ],
  },
  {
    description: "ctrl",
    "type": "basic",
    "from": {
      "pointing_button": "button1",
      "modifiers": {
        "optional": ["any"],
      },
    },
    "to": [
      {
        "pointing_button": "button1",
        "modifiers": [
          "left_control",
        ],
      },
    ],
    "conditions": [
      { "type": "variable_if", "name": "button3_down", "value": 1 },
    ],
  },
] as const;

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
    ],
  },
  {
    description: "スクショ or 録画",
    "type": "basic",
    "from": {
      "pointing_button": "button3",
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
      { "type": "variable_if", "name": "button7_down", "value": 1 },
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
      { "type": "variable_if", "name": "button7_down", "value": 1 },
    ],
  },
  {
    description: "Total spaces",
    "from": {
      "pointing_button": "button2",
      "modifiers": {
        "optional": ["any"],
      },
    },
    "type": "basic",
    to: [
      {
        key_code: "spacebar",
        modifiers: ["shift", "option"],
      },
    ],
    "conditions": [
      { "type": "variable_if", "name": "button7_down", "value": 1 },
    ],
  },
] as const;

const ist = [
  ...button7,
  ...button2,
  ...button3,
  {
    description: "popClip",
    from: {
      "pointing_button": "button6",
    },
    type: "basic",
    "to": [
      {
        shell_command: `osascript -e 'tell application "PopClip" to appear'`,
      },
    ],
  },
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

const globalShortCut = [
  {
    from: {
      key_code: "j",
      modifiers: {
        mandatory: ["control"],
      },
    },
    type: "basic",
    to: [
      {
        key_code: "return_or_enter",
      },
    ],
  },
  {
    from: {
      key_code: "h",
      modifiers: {
        mandatory: ["control"],
      },
    },
    type: "basic",
    to: [
      {
        key_code: "delete_or_backspace",
      },
    ],
  },
  {
    from: {
      key_code: "d",
      modifiers: {
        mandatory: ["control"],
      },
    },
    type: "basic",
    to: [
      {
        key_code: "delete_forward",
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
  ...globalShortCut,
  ...mousePointerJump,
] as const;
