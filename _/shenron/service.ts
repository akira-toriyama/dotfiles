import * as zx from "npm:zx";

export const getShenronRoot = () =>
    [zx.$.sync`chezmoi source-path`.stdout.replace(/\n/g, ""), "/_/shenron"]
        .join("");
