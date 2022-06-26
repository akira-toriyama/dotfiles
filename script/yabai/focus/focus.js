const { pathMap } = require("../../karabiner/config");
const exec = require("util").promisify(require("child_process").exec);

const direction = {
  left: ([currentWindow, ...windows]) =>
    windows.find((v) => v.frame.x < currentWindow.frame.x),
  right: ([currentWindow, ...windows]) =>
    windows.find((v) => v.frame.x > currentWindow.frame.x),
  down: ([currentWindow, ...windows]) =>
    windows.find((v) => v.frame.y > currentWindow.frame.y),
  up: ([currentWindow, ...windows]) =>
    windows.find((v) => v.frame.y < currentWindow.frame.y),
};

module.exports = {
  focusMove: (p) => {
    exec(`${pathMap.yabai} -m query --windows --space`)
      .then((v) => JSON.parse(v.stdout))
      // fig除外
      .then((v) =>
        v.filter(
          (v) => (v.app === "fig" && v["can-resize"] === false) === false
        )
      )
      .then(direction[p.direction])
      .then(
        (v) =>
          v !== undefined && exec(`${pathMap.yabai} -m window --focus ${v.id}`)
      )
      .catch(console.log);
  },
};
