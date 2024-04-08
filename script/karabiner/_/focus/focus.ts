import * as config from "../../config.ts";

type DirectionFn = (pa: Array<FindWindowsResult>) => void;
const left: DirectionFn = ([currentWindow, ...windows]) =>
  windows.find((v) => v.frame.x < currentWindow.frame.x);

const right: DirectionFn = ([currentWindow, ...windows]) =>
  windows.find((v) => v.frame.x > currentWindow.frame.x);

const down: DirectionFn = ([currentWindow, ...windows]) =>
  windows.find((v) => v.frame.y > currentWindow.frame.y);

const up: DirectionFn = ([currentWindow, ...windows]) =>
  windows.find((v) => v.frame.y < currentWindow.frame.y);

const direction = {
  left,
  right,
  down,
  up,
} as const;

/**
 * 一部抜粋
 */
type FindWindowsResult = {
  id: number;
  app: string;
  "can-resize": boolean;
  frame: { x: number; y: number; w: number; h: number };
};

const findWindows = async () => {
  const command = new Deno.Command(config.pathMap.yabai, {
    args: ["-m", "query", "--windows", "--space"],
  });

  const { code, stdout } = await command.output();

  if (code === 0) {
    const r = new TextDecoder().decode(stdout);
    return JSON.parse(r) as Array<FindWindowsResult>;
  }
  return [];
};

const focusMover = async (pa: FindWindowsResult) => {
  const command = new Deno.Command(config.pathMap.yabai, {
    args: ["-m", "window", "--focus", `${pa.id}`],
  });

  const { code, stdout } = await command.output();

  if (code === 0) {
    const r = new TextDecoder().decode(stdout);
    return JSON.parse(r) as Array<FindWindowsResult>;
  }
};

export const focusMove = (p: { direction: keyof typeof direction }) => {
  findWindows()
    // fig除外
    .then((v) =>
      v.filter(
        (v) => (v.app === "fig" && v["can-resize"] === false) === false,
      )
    )
    .then(direction[p.direction])
    .then((v) => {
      v !== undefined && focusMover(v);
    });
};
