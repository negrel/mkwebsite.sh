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
    }:
    let
      outputsWithoutSystem = { };
      outputsWithSystem = flake-utils.lib.eachDefaultSystem (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
          mkwebsiteInputs = with pkgs; [
            coreutils
            bash
            lighttpd
            log4bash.packages.${system}.default
          ];
        in
        {
          packages = {
            default = pkgs.writeShellApplication {
              runtimeInputs = mkwebsiteInputs;
              name = "mkwebsite.sh";
              text = (builtins.readFile ./mkwebsite.sh);
            };
            mod_css = pkgs.writeText "css" (builtins.readFile ./modules.d/css);
            mod_template = pkgs.writeText "minify" (builtins.readFile ./modules.d/template);
            mod_log = pkgs.writeText "minify" (builtins.readFile ./modules.d/log);
            mod_minify = pkgs.writeText "minify" (builtins.readFile ./modules.d/minify);
          };
          devShells = {
            default = pkgs.mkShell {
              buildInputs =
                with pkgs;
                [
                  shellcheck
                  minify
                ]
                ++ mkwebsiteInputs;
            };
          };
        }
      );
    in
    outputsWithSystem // outputsWithoutSystem;
}
