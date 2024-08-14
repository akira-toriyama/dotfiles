import * as config from "./config.ts";
import * as service from "../_/service.ts";

const chezmoiRoot = service.getChezmoiRoot();

const rightClick = [
  /**
   * 右クリでレイヤー切り替え
   */
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
  //
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
  //
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
  //
  {
    description: "Total spaces",
    "from": {
      "pointing_button": "button3",
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
      { "type": "variable_if", "name": "button2_down", "value": 1 },
    ],
  },
] as const;

const mouse = [
  {
    from: {
      key_code: config.keyMap.oLl.keys.s,
      "modifiers": {
        mandatory: config.keyMap.oLl.modifiers,
      },
    },
    type: "basic",
    to: [
      {
        "mouse_key": {
          "x": -700,
        },
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.oLl.keys.d,
      "modifiers": {
        mandatory: config.keyMap.oLl.modifiers,
      },
    },
    type: "basic",
    to: [
      {
        "mouse_key": {
          "y": 700,
        },
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.oLl.keys.f,
      "modifiers": {
        mandatory: config.keyMap.oLl.modifiers,
      },
    },
    type: "basic",
    to: [
      {
        "mouse_key": {
          "x": 700,
        },
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.oLl.keys.e,
      "modifiers": {
        mandatory: config.keyMap.oLl.modifiers,
      },
    },
    type: "basic",
    to: [
      {
        "mouse_key": {
          "y": -700,
        },
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.oLl.keys.leftArrow,
      "modifiers": {
        mandatory: config.keyMap.oLl.modifiers,
      },
    },
    type: "basic",
    to: [
      {
        "mouse_key": {
          "horizontal_wheel": 32,
        },
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.oLl.keys.rightArrow,
      "modifiers": {
        mandatory: config.keyMap.oLl.modifiers,
      },
    },
    type: "basic",
    to: [
      {
        "mouse_key": {
          "horizontal_wheel": -32,
        },
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.oLl.keys.upArrow,
      "modifiers": {
        mandatory: config.keyMap.oLl.modifiers,
      },
    },
    type: "basic",
    to: [
      {
        "mouse_key": {
          "vertical_wheel": -32,
        },
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.oLl.keys.downArrow,
      "modifiers": {
        mandatory: config.keyMap.oLl.modifiers,
      },
    },
    type: "basic",
    to: [
      {
        "mouse_key": {
          "vertical_wheel": 32,
        },
      },
    ],
  },
];

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
    key_code: config.keyMap.delete.keys[v.key],
    modifiers: {
      mandatory: config.keyMap.delete.modifiers,
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
      key_code: config.keyMap.layer.keys.sym2,
      modifiers: {
        mandatory: config.keyMap.layer.modifiers,
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
    description: "alt + tab current スペース",
    from: {
      key_code: config.keyMap.layer.keys.num,
      modifiers: {
        mandatory: config.keyMap.layer.modifiers,
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
      key_code: config.keyMap.layer.keys.sym1,
      modifiers: {
        mandatory: config.keyMap.layer.modifiers,
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
];

const soundEffect = [
  {
    "type": "basic",
    "from": {
      "key_code": "lang3",
    },
    "to": [
      {
        shell_command:
          `${config.pathMap.afplay} --volume 0.1 ${chezmoiRoot}/_/soundEffect/to_mouse_layer.mp3 &`,
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
          `${config.pathMap.afplay} --volume 0.1 ${chezmoiRoot}/_/soundEffect/to_default_layer.mp3 &`,
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
  ...tabSwitching,
  ...rightClick,
  ...spaces,
  ...appSwitching,
  ...windowPosition,
  ...windowFocus,
  ...mouse,
  ...app,
  ...shortCut,
  ...soundEffect,
  ...focusSwitching,
] as const;
