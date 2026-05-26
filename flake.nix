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
      # ホスト識別子は LocalHostName を使用（ASCII 安全）。
      # ComputerName ("tommyのMac mini") は日本語を含み Nix 属性名に不適。
      hostname = "tominoMac-mini";

      # 1ホスト分の darwinSystem を組み立てる共通工場。
      # ci variant では user が "runner" になり、host module で masApps を空にする等の上書きを足す。
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
    in
    {
      # 通常ホスト（実機）
      darwinConfigurations.${hostname} = mkDarwin {
        username = "tommy";
        hostModule = ./system/hosts/${hostname}.nix;
      };

      # 利便用エイリアス（install.sh から `--flake .#default` で参照）
      darwinConfigurations.default = self.darwinConfigurations.${hostname};

      # CI 用: GitHub Actions の macos-latest runner で switch をスモークテストする。
      # 違い:
      #   - username = "runner" (runner ホスト OS のユーザー)
      #   - host module は ci.nix (アーキ等は共有、user 名のみ差し替え)
      #   - masApps は空 (App Store サインインができない CI で落ちないように)
      darwinConfigurations.ci = mkDarwin {
        username = "runner";
        hostModule = ./system/hosts/ci.nix;
        extraModules = [
          ({ lib, ... }: {
            # CI では App Store サインインができないので masApps を空に
            homebrew.masApps = lib.mkForce { };
            # CI runner の brew メタデータは古い可能性があるので毎回 update
            # (実機の通常 switch には影響なし)
            homebrew.onActivation.autoUpdate = lib.mkForce true;
          })
        ];
      };
    };
}
