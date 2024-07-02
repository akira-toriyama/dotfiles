import { generate } from "https://deno.land/x/shenron/mod.ts";
import { parseArgs } from "jsr:@std/cli/parse-args";
import { $ as zx } from "npm:zx";

const getParam = () => {
    const home = Deno.env.get("HOME");
    const flags = parseArgs(Deno.args, { string: ["accountName"] });

    if (!home) {
        throw new Error("home");
    }

    if (!flags.accountName) {
        throw new Error("accountName");
    }

    return {
        home,
        flags: {
            accountName: flags.accountName,
        },
    };
};

const p = getParam();

await generate({
    path: {
        output: `${p.home}/.ssh`,
        template: `${p.home}/dotfiles/template/ssh/conf.d`,
    },
    replacements: [{
        before: "__name__",
        after: p.flags.accountName,
    }],
});

await generate({
    path: {
        output: `${p.home}/.config`,
        template: `${p.home}/dotfiles/template/git`,
    },
    replacements: [{
        before: "__name__",
        after: p.flags.accountName,
    }],
});

await zx`git config --global includeIf."gitdir:/Volumes/workspace/github.com/${p.flags.accountName}/".path "~/.config/git/user/${p.flags.accountName}"`;
await zx`git config --global url."ssh://git@github.com.${p.flags.accountName}/${p.flags.accountName}".insteadOf "ssh://git@github.com/${p.flags.accountName}"`;
await zx`ssh-keygen -t ed25519 -N "" -f "${p.home}/.ssh/conf.d/hosts/github.com.${p.flags.accountName}/id_rsa"`;

console.log(
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
);
console.log(
    "GitHubにkeyを登録する。",
);
console.log(
    `pbcopy < "${p.home}/.ssh/conf.d/hosts/github.com.${p.flags.accountName}/id_rsa.pub"`,
);
console.log(
    "open https://github.com/settings/keys",
);

console.log(
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
);
console.log(
    `~/.config/git/user/${p.flags.accountName} のemailを設定`,
);

console.log(
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
);
await zx`ls -la ${p.home}/.ssh/conf.d/hosts`.then((v) => console.log(v.stdout));

console.log(
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
);
await zx`cat ~/.gitconfig`.then((v) => console.log(v.stdout));
