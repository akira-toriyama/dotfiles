const exec = require("util").promisify(require("child_process").exec);

const findWindowCoordinate = () =>
  exec("yabai -m query --windows --window")
    .then((v) => JSON.parse(v.stdout))
    .then((v) => ({
      ...v.frame,
    }))
    .catch(console.log);

const randRange = () => {
  const min = 5;
  const max = 10;

  return Math.floor(Math.random() * (max - min + 1) + min);
};

const sleep = () => new Promise((resolve) => setTimeout(resolve, 100));

(async () => {
  // ズレる場合があるので待つ
  await sleep();
  const { x, y } = await findWindowCoordinate();

  await Promise.resolve()
    .then(() =>
      exec(`yabai -m window --move abs:${x + randRange()}:${y + randRange()}`)
    )
    .then(() =>
      exec(`yabai -m window --move abs:${x - randRange()}:${y - randRange()}`)
    )
    // ズレる場合があるので、しつこく元の場所に戻す
    .then(() => {
      exec(`yabai -m window --move abs:${x}:${y}`);
    })
    .catch(() => {
      exec(`yabai -m window --move abs:${x}:${y}`);
    })
    .finally(() => {
      exec(`yabai -m window --move abs:${x}:${y}`);
    });

  exec(`yabai -m window --move abs:${x}:${y}`);
})();
