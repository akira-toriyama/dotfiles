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

const focusSwitching = [
  {
    from: {
      key_code: config.keyMap.f,
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
      key_code: config.keyMap.d,
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

const _rectangle3 = [
  {
    from: {
      key_code: config.keyMap.s,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        shell_command: 'open -g "rectangle://execute-action?name=first-third"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.d,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        shell_command: 'open -g "rectangle://execute-action?name=center-third"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.f,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        shell_command: 'open -g "rectangle://execute-action?name=last-third"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.a,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        shell_command:
          'open -g "rectangle://execute-action?name=first-two-thirds"',
      },
    ],
  },
  {
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
          'open -g "rectangle://execute-action?name=last-two-thirds"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.w,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        shell_command:
          'open -g "rectangle://execute-action?name=top-left-sixth"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.e,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        shell_command:
          'open -g "rectangle://execute-action?name=top-center-sixth"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.r,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        shell_command:
          'open -g "rectangle://execute-action?name=top-right-sixth"',
      },
    ],
  },

  {
    from: {
      key_code: config.keyMap.x,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        shell_command:
          'open -g "rectangle://execute-action?name=bottom-left-sixth"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.c,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        shell_command:
          'open -g "rectangle://execute-action?name=bottom-center-sixth"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.v,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        shell_command:
          'open -g "rectangle://execute-action?name=bottom-right-sixth"',
      },
    ],
  },
] as const;

const _rectangle2n4 = [
  {
    from: {
      key_code: config.keyMap.s,
      modifiers: {
        mandatory: config.keyMap.del,
      },
    },
    type: "basic",
    to: [
      {
        shell_command: 'open -g "rectangle://execute-action?name=left-half"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.d,
      modifiers: {
        mandatory: config.keyMap.del,
      },
    },
    type: "basic",
    to: [
      {
        shell_command: 'open -g "rectangle://execute-action?name=center-half"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.f,
      modifiers: {
        mandatory: config.keyMap.del,
      },
    },
    type: "basic",
    to: [
      {
        shell_command: 'open -g "rectangle://execute-action?name=right-half"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.a,
      modifiers: {
        mandatory: config.keyMap.del,
      },
    },
    type: "basic",
    to: [
      {
        shell_command:
          'open -g "rectangle://execute-action?name=first-three-fourths"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.g,
      modifiers: {
        mandatory: config.keyMap.del,
      },
    },
    type: "basic",
    to: [
      {
        shell_command:
          'open -g "rectangle://execute-action?name=last-three-fourths"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.z,
      modifiers: {
        mandatory: config.keyMap.del,
      },
    },
    type: "basic",
    to: [
      {
        shell_command: 'open -g "rectangle://execute-action?name=first-fourth"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.x,
      modifiers: {
        mandatory: config.keyMap.del,
      },
    },
    type: "basic",
    to: [
      {
        shell_command:
          'open -g "rectangle://execute-action?name=second-fourth"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.c,
      modifiers: {
        mandatory: config.keyMap.del,
      },
    },
    type: "basic",
    to: [
      {
        shell_command: 'open -g "rectangle://execute-action?name=third-fourth"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.v,
      modifiers: {
        mandatory: config.keyMap.del,
      },
    },
    type: "basic",
    to: [
      {
        shell_command: 'open -g "rectangle://execute-action?name=last-fourth"',
      },
    ],
  },
] as const;

const _rectangleOther = [
  {
    from: {
      key_code: config.keyMap.q,
      modifiers: {
        mandatory: config.keyMap.tab,
      },
    },
    type: "basic",
    to: [
      {
        shell_command: 'open -g "rectangle://execute-action?name=maximize"',
      },
    ],
  },
  {
    from: {
      key_code: config.keyMap.q,
      modifiers: {
        mandatory: config.keyMap.del,
      },
    },
    type: "basic",
    to: [
      {
        shell_command:
          'open -g "rectangle://execute-action?name=almost-maximize"',
      },
    ],
  },
] as const;

const rectangle = [
  ..._rectangle3,
  ..._rectangle2n4,
  ..._rectangleOther,
] as const;

export const manipulators = [
  ...tabSwitching,
  ...rightClick,
  ...totalSpaces,
  ...altTab,
  ...rectangle,
  ...focusSwitching,
];
