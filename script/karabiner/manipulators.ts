import * as config from "./config.ts";

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

const tabSwitching = [
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

const totalSpaces = [
  {
    description: "All spaces",
    from: {
      key_code: config.keyMap.ll,
    },
    type: "basic",
    to: [
      {
        key_code: "spacebar",
        modifiers: ["option", "shift"],
      },
    ],
  },
  /**
   * focus
   */
  ...config.spaces.map((v, k) => ({
    keyCode: v,
    no: k + 1,
  })).map(({ keyCode, no }) => ({
    description: `focus spaces ${no}`,
    from: {
      key_code: keyCode,
      modifiers: {
        mandatory: ["control"],
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
  ...config.spaces.map((v, k) => ({
    keyCode: v,
    no: k + 1,
  })).map(({ keyCode, no }) => ({
    description: `focus spaces ${no}`,
    from: {
      key_code: keyCode,
      modifiers: {
        mandatory: ["option"],
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
  ...config.spaces.map((v, k) => ({
    keyCode: v,
    no: k + 1,
  })).map(({ keyCode, no }) => ({
    description: `focus spaces ${no}`,
    from: {
      key_code: keyCode,
      modifiers: {
        mandatory: ["option", "control"],
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

const altTab = [
  {
    description: "alt + tab current スペース",
    from: {
      key_code: config.keyMap.ll,
      modifiers: {
        mandatory: ["shift"],
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
        mandatory: ["command"],
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

const windowPosition = config.window.map((v) => ({
  from: {
    key_code: config.keyMap[v.key],
    modifiers: {
      mandatory: config.keyMap.tab,
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
    key_code: config.keyMap[v.key],
    modifiers: {
      mandatory: config.keyMap.del,
    },
  },
  type: "basic",
  to: [
    {
      shell_command:
        `${config.pathMap.deno} run --allow-run ${config.pathMap.dotfiles}/script/karabiner/_/focus.ts ${v.key}`,
    },
  ],
}));

export const manipulators = [
  ...tabSwitching,
  ...rightClick,
  ...totalSpaces,
  ...altTab,
  ...windowPosition,
  ...windowFocus,
] as const;
