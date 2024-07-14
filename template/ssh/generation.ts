// deno run --allow-run --allow-read --allow-write --allow-env --allow-sys $HOME/dotfiles/template/ssh/generation.ts

import * as shenron from "https://deno.land/x/shenron@v2.1.0/mod.ts";
import * as zx from "npm:zx";
import * as cliffyPrompt from "https://deno.land/x/cliffy@v1.0.0-rc.4/prompt/mod.ts";

const accountName = await cliffyPrompt.Input.prompt({
    message: "accountName",
    validate: (o) => 0 < o.length ? true : "必須",
});

const home = Deno.env.get("HOME");

const p = {
    accountName,
    dir: {
        home,
        template: `${home}/dotfiles/template/ssh`,
    },
} as const;

await shenron.generate({
    dir: {
        output: `${p.dir.home}`,
        template: `${p.dir.template}/.ssh`,
    },
    replacements: [{
        before: "__name__",
        after: p.accountName,
    }],
});

await shenron.generate({
    dir: {
        output: `${p.dir.home}`,
        template: `${p.dir.template}/.config`,
    },
    replacements: [{
        before: "__name__",
        after: p.accountName,
    }],
});

await zx
    .$`git config --global includeIf."gitdir:/Volumes/workspace/github.com/${p.accountName}/".path "~/.config/git/user/${p.accountName}"`;
await zx
    .$`git config --global url."ssh://git@github.com.${p.accountName}/${p.accountName}".insteadOf "ssh://git@github.com/${p.accountName}"`;
await zx
    .$`ssh-keygen -t ed25519 -N "" -f "${p.dir.home}/.ssh/conf.d/hosts/github.com.${p.accountName}/id_rsa"`;

console.log(
    "公開鍵をコピー",
);
console.log(
    `pbcopy < "${p.dir.home}/.ssh/conf.d/hosts/github.com.${p.accountName}/id_rsa.pub"`,
);
console.log("");

console.log(
    "GitHubにkeyを登録",
);
console.log(
    "https://github.com/settings/keys",
);
console.log("");

console.log(
    "git commit用のメアドを登録",
);
console.log(
    `vim ${p.dir.home}/.config/git/user/${p.accountName}`,
);
