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
      username = "tommy";
    in
    {
      darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
        modules = [
          ./system/hosts/${hostname}.nix

          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit username; };
            home-manager.users.${username} = import ./home/modules;
          }

          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              enableRosetta = true;
              user = username;
              autoMigrate = true; # 既存 /opt/homebrew を吸収
            };
          }
        ];
        specialArgs = { inherit username; };
      };

      # 利便用エイリアス
      darwinConfigurations.default = self.darwinConfigurations.${hostname};
    };
}
