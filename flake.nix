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
      # 既知の実機ホスト識別子 (LocalHostName 由来、ASCII 安全)。
      # tommy の現用 Mac mini。新 PC では .#default 経由で動的に user を解決する。
      hostname = "tominoMac-mini";

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

      # 新 PC bootstrap / CI / Tart VM 共通の brew override。
      #   - autoUpdate=true: 新規環境では cask メタデータが古い (上流 cask 更新
      #     直後だと checksum mismatch で brew bundle fetch が失敗する)。
      #     activation の度に brew update を強制して fresh metadata を引く。
      #   - masApps 空: 1Password など App Store サインインが必要な mas は
      #     bootstrap/CI/VM の文脈ではセットアップできない、強制空に。
      # tominoMac-mini (tommy の実機・常用) は override 不要 (autoUpdate=false 既定)。
      bootstrapBrewOverride = { lib, ... }: {
        homebrew.masApps = lib.mkForce { };
        homebrew.onActivation.autoUpdate = lib.mkForce true;
      };
    in
    {
      # 既知の実機 (tommy の Mac mini)。明示的に host 名を指す場合用。
      # autoUpdate=false の常用ホスト (頻繁な brew 更新を避ける、既定)。
      darwinConfigurations.${hostname} = mkDarwin {
        username = "tommy";
        hostModule = ./system/hosts/${hostname}.nix;
      };

      # 新 PC ブートストラップ用: install.sh が `--flake .#default --impure` で呼ぶ。
      # username は detectUser (FLAKE_USER → USER → "tommy") で実行時解決するため、
      # 任意ユーザー名の Mac (= tommy 以外の新 PC や会社 PC) でもそのまま動く。
      # 既存 tommy の Mac でも `USER=tommy` なので同じ結果になり、後方互換あり。
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
