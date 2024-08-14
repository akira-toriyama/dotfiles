import * as zx from "npm:zx";

export const getChezmoiRoot = () =>
    zx.$.sync`chezmoi source-path`.stdout.replace(/\n/g, "");
