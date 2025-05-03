{
  description = "Static site generator in bash";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    log4bash.url = "github:negrel/log4bash";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      log4bash,
      ...
    }@inputs:
    let
      outputsWithoutSystem = { };
      outputsWithSystem = flake-utils.lib.eachDefaultSystem (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
          lib = pkgs.lib;
        in
        {
          devShells = {
            default = pkgs.mkShell {
              buildInputs = with pkgs; [
                minify
                lighttpd
                shellcheck
                log4bash.packages.${system}.default
              ];
            };
          };
        }
      );
    in
    outputsWithSystem // outputsWithoutSystem;
}
