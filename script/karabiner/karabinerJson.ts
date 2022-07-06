import { pathMap } from "./config.ts";

const keyMap = {
  0: "keypad_0",
  qq: "non_us_backslash", // qの左
  q: "keypad_1",
  w: "keypad_2",
  e: "keypad_3",
  r: "keypad_4",
  t: "keypad_5",
  aa: "keypad_num_lock", // aの左
  a: "keypad_6",
  s: "keypad_7",
  d: "keypad_8",
  f: "keypad_9",
  g: "keypad_plus",
  zz: "keypad_enter", // zの左
  z: "keypad_equal_sign",
  x: "keypad_period",
  c: "keypad_hyphen",
  v: "keypad_slash",
  b: "keypad_asterisk",
  del: ["control", "shift", "option", "command"],
  tab: ["control", "shift", "option"],
} as const;

const appMap = {
  Chrome: "^com\\.google\\.Chrome$",
  VSCode: "^com\\.microsoft\\.VSCode$",
  FSNotes: "^co\\.fluder\\.FSNotes$",
} as const;

const karabinerJson = {
  global: {
    check_for_updates_on_startup: true,
    show_in_menu_bar: true,
    show_profile_name_in_menu_bar: false,
  },
  profiles: [
    {
      complex_modifications: {
        parameters: {
          "basic.simultaneous_threshold_milliseconds": 50,
          "basic.to_delayed_action_delay_milliseconds": 500,
          "basic.to_if_alone_timeout_milliseconds": 1000,
          "basic.to_if_held_down_threshold_milliseconds": 500,
          "mouse_motion_to_scroll.speed": 100,
        },
        rules: [
          {
            description: "dactyl",
            manipulators: [
              {
                from: {
                  key_code: keyMap.q,
                },
                type: "basic",
                to: [
                  {
                    shell_command:
                      `${pathMap.yabai} -m window --grid 3:1:0:0:3:1`,
                  },
                ],
              },
              {
                from: {
                  key_code: keyMap.q,
                  modifiers: {
                    mandatory: ["shift"],
                  },
                },
                type: "basic",
                to: [
                  {
                    shell_command:
                      `${pathMap.yabai} -m window --grid 3:2:0:0:3:2`,
                  },
                ],
              },
              {
                from: {
                  key_code: keyMap.w,
                },
                type: "basic",
                to: [
                  {
                    shell_command:
                      `${pathMap.yabai} -m window --grid 3:1:0:2:3:1`,
                  },
                ],
              },
              {
                from: {
                  key_code: keyMap.w,
                  modifiers: {
                    mandatory: ["shift"],
                  },
                },
                type: "basic",
                to: [
                  {
                    shell_command:
                      `${pathMap.yabai} -m window --grid 3:1:0:1:3:2`,
                  },
                ],
              },
              {
                from: {
                  key_code: keyMap.e,
                },
                type: "basic",
                to: [
                  {
                    shell_command:
                      `${pathMap.yabai} -m window --grid 1:3:0:0:1:3`,
                  },
                ],
              },
              {
                from: {
                  key_code: keyMap.e,
                  modifiers: {
                    mandatory: ["shift"],
                  },
                },
                type: "basic",
                to: [
                  {
                    shell_command:
                      `${pathMap.yabai} -m window --grid 1:3:0:0:2:3`,
                  },
                ],
              },
              {
                from: {
                  key_code: keyMap.r,
                },
                type: "basic",
                to: [
                  {
                    shell_command:
                      `${pathMap.yabai} -m window --grid 1:3:2:0:1:3`,
                  },
                ],
              },
              {
                from: {
                  key_code: keyMap.r,
                  modifiers: {
                    mandatory: ["shift"],
                  },
                },
                type: "basic",
                to: [
                  {
                    shell_command:
                      `${pathMap.yabai} -m window --grid 1:3:1:0:2:3`,
                  },
                ],
              },
              {
                from: {
                  key_code: keyMap.t,
                },
                type: "basic",
                to: [
                  {
                    shell_command:
                      `${pathMap.yabai} -m window --grid 1:3:1:15:1:3`,
                  },
                ],
              },
              {
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
                from: {
                  key_code: keyMap.d,
                  modifiers: {
                    mandatory: keyMap.del,
                  },
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
                from: {
                  key_code: keyMap.d,
                  modifiers: {
                    mandatory: keyMap.del,
                  },
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
              {
                from: {
                  key_code: keyMap.f,
                  modifiers: {
                    mandatory: keyMap.del,
                  },
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
                from: {
                  key_code: keyMap.f,
                  modifiers: {
                    mandatory: keyMap.del,
                  },
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
              {
                from: {
                  key_code: keyMap.z,
                },
                type: "basic",
                to: [
                  {
                    shell_command:
                      `${pathMap.yabai} -m window --grid 2:1:0:0:2:1`,
                  },
                ],
              },
              {
                from: {
                  key_code: keyMap.x,
                },
                type: "basic",
                to: [
                  {
                    shell_command:
                      `${pathMap.yabai} -m window --grid 2:1:0:1:2:1`,
                  },
                ],
              },
              {
                from: {
                  key_code: keyMap.c,
                },
                type: "basic",
                to: [
                  {
                    shell_command:
                      `${pathMap.yabai} -m window --grid 1:2:0:0:1:2`,
                  },
                ],
              },
              {
                from: {
                  key_code: keyMap.v,
                },
                type: "basic",
                to: [
                  {
                    shell_command:
                      `${pathMap.yabai} -m window --grid 1:2:1:0:1:2`,
                  },
                ],
              },
              {
                from: {
                  key_code: keyMap.b,
                },
                type: "basic",
                to: [
                  {
                    shell_command:
                      `${pathMap.yabai} -m window --grid 1:1:0:0:1:1`,
                  },
                ],
              },
              {
                from: {
                  key_code: keyMap.b,
                  modifiers: {
                    mandatory: ["shift"],
                  },
                },
                type: "basic",
                to: [
                  {
                    shell_command:
                      `${pathMap.yabai} -m config layout bsp && ${pathMap.yabai} -m config layout float`,
                  },
                ],
              },
              {
                from: {
                  key_code: keyMap[0],
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
                from: {
                  key_code: keyMap.c,
                  modifiers: {
                    mandatory: keyMap.del,
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
            ],
          },
        ],
      },
      devices: [],
      fn_function_keyMap: [
        {
          from: {
            key_code: "f1",
          },
          to: [
            {
              consumer_key_code: "display_brightness_decrement",
            },
          ],
        },
        {
          from: {
            key_code: "f2",
          },
          to: [
            {
              consumer_key_code: "display_brightness_increment",
            },
          ],
        },
        {
          from: {
            key_code: "f3",
          },
          to: [
            {
              apple_vendor_keyboard_key_code: "mission_control",
            },
          ],
        },
        {
          from: {
            key_code: "f4",
          },
          to: [
            {
              apple_vendor_keyboard_key_code: "spotlight",
            },
          ],
        },
        {
          from: {
            key_code: "f5",
          },
          to: [
            {
              consumer_key_code: "dictation",
            },
          ],
        },
        {
          from: {
            key_code: "f6",
          },
          to: [
            {
              key_code: "f6",
            },
          ],
        },
        {
          from: {
            key_code: "f7",
          },
          to: [
            {
              consumer_key_code: "rewind",
            },
          ],
        },
        {
          from: {
            key_code: "f8",
          },
          to: [
            {
              consumer_key_code: "play_or_pause",
            },
          ],
        },
        {
          from: {
            key_code: "f9",
          },
          to: [
            {
              consumer_key_code: "fast_forward",
            },
          ],
        },
        {
          from: {
            key_code: "f10",
          },
          to: [
            {
              consumer_key_code: "mute",
            },
          ],
        },
        {
          from: {
            key_code: "f11",
          },
          to: [
            {
              consumer_key_code: "volume_decrement",
            },
          ],
        },
        {
          from: {
            key_code: "f12",
          },
          to: [
            {
              consumer_key_code: "volume_increment",
            },
          ],
        },
      ],
      name: "Default profile",
      parameters: {
        delay_milliseconds_before_open_device: 1000,
      },
      selected: true,
      simple_modifications: [],
      virtual_hid_keyboard: {
        country_code: 0,
        indicate_sticky_modifier_keyMap_state: true,
        mouse_key_xy_scale: 100,
      },
    },
  ],
};

console.log(JSON.stringify(karabinerJson));
