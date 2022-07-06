import { pathMap } from "../../karabiner/config.ts";

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
  const p = Deno.run({
    cmd: [pathMap.yabai, "-m", "query", "--windows", "--space"],
    stdout: "piped",
    stderr: "piped",
  });

  const { code } = await p.status();
  p.close();

  if (code !== 0) {
    return [];
  }

  return p.output()
    .then((v) => new TextDecoder().decode(v))
    .then<Array<FindWindowsResult>>((v) => JSON.parse(v));
};

const focusMover = async (pa: FindWindowsResult) => {
  const p = Deno.run({
    cmd: [pathMap.yabai, "-m", "window", "--focus", `${pa.id}`],
    stdout: "piped",
    stderr: "piped",
  });

  await p.status();
  p.close();
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
