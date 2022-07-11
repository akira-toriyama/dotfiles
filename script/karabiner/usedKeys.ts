import { manipulators } from "./manipulators.ts";
import { keyMap } from "./config.ts";

const keys = Object.entries(keyMap);

type Manipulator = typeof manipulators[number];
const modifier = {
  del: (v: Manipulator) =>
    "modifiers" in v.from && JSON.stringify(v.from.modifiers.mandatory) ===
      JSON.stringify(keyMap.del),
  tab: (v: Manipulator) =>
    "modifiers" in v.from && JSON.stringify(v.from.modifiers.mandatory) ===
      JSON.stringify(keyMap.tab),
  um: (v: Manipulator) => "modifiers" in v.from === false,
} as const;

const make = (v: Manipulator) => ({
  key: keys.find(([, vv]) => v.from.key_code === vv)
    ?.at(0)?.toString(),
  description: v.description,
  // @ts-expect-error -- たぶんある
  app: JSON.stringify(v?.conditions),
});

const makeDataWithModify = (p: keyof typeof modifier) =>
  manipulators
    .filter(modifier[p])
    .map(make).sort((a, b) => {
      if (a.key! < b.key!) {
        return -1;
      }
      if (a.key! > b.key!) {
        return 1;
      }
      return 0;
    });

const tab = makeDataWithModify("tab");
const del = makeDataWithModify("del");
const um = makeDataWithModify("um");

console.log({ tab });
console.log({ del });
console.log({ um });

// 未使用キー
