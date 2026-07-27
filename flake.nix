{
  description = "akira-toriyama macOS environment (nix-darwin + home-manager)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    { self, nixpkgs, nix-darwin, home-manager, nix-homebrew }:
    let
      # `darwinConfigurations.default` 用に実行時の user 名を決定する。
      # 優先順:
      #   1. FLAKE_USER 環境変数 (会社 PC 等で明示指定したい場合)
      #   2. SUDO_USER 環境変数 (sudo darwin-rebuild で USER=root 化される問題回避)
      #   3. USER 環境変数 (通常はこれで OK、新 PC でも自動追従)
      #   4. フォールバック "tommy" (env 無し時の互換、評価エラー回避)
      # ※ getEnv 利用のため `--impure` フラグが必須。install.sh で付与する。
      # ※ "root" は users.users.root と衝突するので明示的に弾く。
      detectUser =
        let
          fromFlakeUser = builtins.getEnv "FLAKE_USER";
          fromSudoUser = builtins.getEnv "SUDO_USER";
          fromUser = builtins.getEnv "USER";
          pickNonRoot = v: if v != "" && v != "root" then v else "";
          chosen =
            if fromFlakeUser != "" then fromFlakeUser
            else if pickNonRoot fromSudoUser != "" then fromSudoUser
            else if pickNonRoot fromUser != "" then fromUser
            else "tommy";
        in
        chosen;

      # lint ツールの供給源。CI (x86_64-linux) と開発機 (aarch64-darwin) へ同じ版を配る。
      # 版の正本は flake.lock 1 本 —— 「ローカルで通ったものと CI が別版」が構造的に起きない。
      forLintSystems = f:
        nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ]
          (system: f nixpkgs.legacyPackages.${system});

      # 1ホスト分の darwinSystem を組み立てる共通工場。
      # username が specialArgs に注入され、host module で users.users.${username} と
      # system.primaryUser を構成する。
      mkDarwin = { username, hostModule, extraModules ? [ ] }:
        nix-darwin.lib.darwinSystem {
          modules = [
            hostModule

            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit username; };
              home-manager.backupFileExtension = "hm-backup";
              home-manager.users.${username} = import ./home/modules;
            }

            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                enableRosetta = true;
                user = username;
                autoMigrate = true;
              };
            }
          ] ++ extraModules;
          specialArgs = { inherit username; };
        };

      # bootstrap / 常用 / CI / Tart VM 共通の brew override。
      #   - autoUpdate=true: cask メタデータが古いと上流 cask 更新直後に
      #     checksum mismatch で brew bundle fetch が失敗する。activation の
      #     度に brew update を強制して fresh metadata を引く。
      #   - masApps 空: App Store サインインが必要な mas install は bootstrap/CI/VM
      #     の文脈では成立しないため強制空に（現在 MAS アプリ利用ゼロ、宣言も空）。
      bootstrapBrewOverride = { lib, ... }: {
        homebrew.masApps = lib.mkForce { };
        homebrew.onActivation.autoUpdate = lib.mkForce true;
      };
    in
    {
      # 日常 + 新 PC ブートストラップ共通: install.sh が `--flake .#default --impure` で呼ぶ。
      # username は detectUser (FLAKE_USER → USER → "tommy") で実行時解決するため、
      # 任意ユーザー名の Mac (= tommy 以外の新 PC や会社 PC) でもそのまま動く。
      # bootstrap override (autoUpdate=true, masApps 空) を適用、新規環境で
      # 確実に cask が fetch できる + App Store サインイン不要構成。
      darwinConfigurations.default = mkDarwin {
        username = detectUser;
        hostModule = ./system/hosts/generic.nix;
        extraModules = [ bootstrapBrewOverride ];
      };

      # CI 用: GitHub Actions の macos-latest runner で switch をスモークテストする。
      # username = "runner" (env に依存させず固定)、override は default と共通。
      darwinConfigurations.ci = mkDarwin {
        username = "runner";
        hostModule = ./system/hosts/generic.nix;
        extraModules = [ bootstrapBrewOverride ];
      };

      # `nix develop .#lint --command scripts/lint` が食う shell。CI の lint job も同じ経路。
      # ここに宣言したものだけが PATH に載るので、開発機の brew 版（PATH は
      # /opt/homebrew/bin が nix profile より前）が混ざらない —— 検査ツールを
      # home.packages に足さずに済むのはこの隔離のおかげ。
      # python313 を明示するのは、mypy の伝播依存で漏れてくる python が 3.14 で、
      # 「既定は Python 3.13」の方針と食い違うため（暗黙 leak に乗らない）。
      devShells = forLintSystems (pkgs: {
        lint = pkgs.mkShellNoCC {
          packages = [
            pkgs.python313
            pkgs.ruff
            pkgs.mypy
            pkgs.shfmt
            pkgs.shellcheck
            pkgs.actionlint
            pkgs.typos
            pkgs.lychee
            pkgs.gitleaks
          ];
        };
      });

      # install.sh が locked nix-darwin から darwin-rebuild を起動するための passthrough。
      # `nix run nix-darwin/master#darwin-rebuild` は実行時に master を解決する rolling
      # 参照で、pin×rolling の不安定（brew 5.1.11 事故と同型）+ 未認証 api.github.com
      # 403 リスクがあった。ここを経由すれば flake.lock の nix-darwin が使われる。
      packages.aarch64-darwin.darwin-rebuild =
        nix-darwin.packages.aarch64-darwin.darwin-rebuild;
    };
}
