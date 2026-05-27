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
      #   2. USER 環境変数 (通常はこれで OK、新 PC でも自動追従)
      #   3. フォールバック "tommy" (env 無し時の互換、評価エラー回避)
      # ※ getEnv 利用のため `--impure` フラグが必須。install.sh で付与する。
      detectUser =
        let
          fromFlakeUser = builtins.getEnv "FLAKE_USER";
          fromUser = builtins.getEnv "USER";
        in
        if fromFlakeUser != "" then fromFlakeUser
        else if fromUser != "" then fromUser
        else "tommy";

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
      #   - masApps 空: 1Password など App Store サインインが必要な mas は
      #     bootstrap/CI/VM の文脈ではセットアップできず、`mas 1.8.6` は
      #     macOS 15+ で `mas get/install` が壊れているため強制空に。
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
    };
}
