import { manipulators } from "../karabiner/manipulators.ts";
import * as config from "../karabiner/config.ts";

manipulators.filter((v) => "description" in v).map((v) => {
  const modifier = v.from.modifiers
    ? v.from.modifiers.mandatory?.join(",")
    : "ll";

  const keyCode = Object.entries(config.keyMap).find(([kk, vv]) =>
    vv === v.from.key_code
  )?.at(
    0,
  );

  console.log(`## ${v.description}`);
  console.log("```");
  console.log([modifier, keyCode].join(" & "));
  console.log("```");
});
