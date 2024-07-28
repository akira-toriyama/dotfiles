import * as config from "../config.ts";

const switchFocus = (p: { id: number }) => {
  new Deno.Command(config.pathMap.yabai, {
    args: ["-m", "window", "--focus", `${p.id}`],
  }).output();
};

type Window = {
  id: number;
  "has-focus": boolean;
  frame: {
    x: number;
    y: number;
    w: number;
    h: number;
  };
};
const getWindows = async () => {
  const command = new Deno.Command(config.pathMap.yabai, {
    args: ["-m", "query", "--windows", "--space"],
  });

  const { code, stdout } = await command.output();

  if (code === 0) {
    const r = new TextDecoder().decode(stdout);
    return JSON.parse(r) as Array<Window>;
  }
  return [];
};

type GetInputtedKey = () => typeof config["window"][number]["key"];
// @ts-expect-error -- タイプガードする程ではない
const getInputtedKey: GetInputtedKey = () => Deno.args[0];

const getTarget = () => {
  const inputtedKey = getInputtedKey();
  return config.window.find((v) => v.key === inputtedKey);
};

const focus = () => {
  const target = getTarget();
  if (!target?.frame) {
    return;
  }

  getWindows().then((r) => {
    const windows = r
      .filter((v) =>
        v.frame.x === target.frame.x && v.frame.y === target.frame.y &&
        v.frame.h === target.frame.h && v.frame.w === target.frame.w
      )
      .filter((v) => !v["has-focus"]);

    const no = windows.length - 1;
    if (!windows[no]?.id) {
      return;
    }
    switchFocus({ id: windows[no].id });
  });
};
focus();
