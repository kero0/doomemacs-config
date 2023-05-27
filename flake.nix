{
  description = "nix-doom-emacs shell";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    nix-doom-emacs = {
      url = "github:nix-community/nix-doom-emacs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        emacs-overlay.follows = "emacs-overlay";
        flake-utils.follows = "flake-utils";
        doom-emacs.url = "github:doomemacs/doomemacs";
        org.url = "github:emacs-straight/org-mode";
        org-contrib.url = "github:emacsmirror/org-contrib";
        evil-org-mode.url = "github:hlissner/evil-org-mode";
      };
    };
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    # elisp package sources
    copilot = {
      url = "github:zerolfx/copilot.el";
      flake = false;
    };
    ox-chameleon = {
      url = "github:tecosaur/ox-chameleon";
      flake = false;
    };

    # just temporary
    evil-collection = {
      url = "github:emacs-evil/evil-collection";
      flake = false;
    };
    consult = {
      url = "github:minad/consult/994f800a59924ed2683324deab39810fdc760d5d";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-doom-emacs, emacs-overlay, ... }:
    let
      doom-emacs = system: pkgs:
        let
          emacs = (pkgs.emacs.override {
            withPgtk = true;
            withXwidgets = true;
            withWebP = true;
          }).overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ])
              ++ (pkgs.lib.optional pkgs.stdenv.isDarwin [
                pkgs.darwin.apple_sdk.frameworks.Cocoa
                pkgs.darwin.apple_sdk.frameworks.WebKit
              ]);
            patches = (old.patches or [ ])
              ++ (pkgs.lib.optional pkgs.stdenv.isDarwin [
                # Fix OS window role (needed for window managers like yabai)
                (pkgs.fetchpatch {
                  url =
                    "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/emacs-28/fix-window-role.patch";
                  sha256 = "+z/KfsBm1lvZTZNiMbxzXQGRTjkCFO4QPlEK35upjsE=";

                })
                # Make Emacs aware of OS-level light/dark mode
                (pkgs.fetchpatch {
                  url =
                    "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/emacs-28/system-appearance.patch";
                  sha256 = "oM6fXdXCWVcBnNrzXmF0ZMdp8j0pzkLE66WteeCutv8=";
                })
              ]);
          });
          mkTrivialPkg = { pkgs, name, src ? inputs.${name}, buildInputs ? [ ]
            , extraFiles ? [ ] }:
            ((pkgs.trivialBuild {
              inherit buildInputs;
              pname = name;
              ename = name;
              version = "0.0.0";
              src = src;
            }).overrideAttrs (old: {
              installPhase = old.installPhase + (builtins.concatStringsSep "\n"
                (map (s: ''cp -r "${s}" "$LISPDIR"'') extraFiles));
            }));
          lisp-packages = with pkgs;
            [ lilypond-unstable mu ] ++ (with (pkgs.emacsPackagesFor emacs); [
              coreutils-full
              editorconfig
              elisp-demos
            ]);
          all-packages = lisp-packages ++ (import ./dependencies pkgs);
          doom-emacs = rec {
            doomPrivateDir = ./.;
            doomPackageDir = pkgs.linkFarm "doom-package-dir" [
              {
                name = "config.el";
                path = pkgs.emptyFile;
              }
              {
                name = "init.el";
                path = "${doomPrivateDir}/init.el";
              }
              {
                name = "packages.el";
                path = "${doomPrivateDir}/packages.el";
              }
            ];
            # load PATH in extra config
            extraConfig = ''
              (setenv "PATH" (concat (getenv "PATH") ":${
                nixpkgs.lib.makeBinPath all-packages
              }"))
            '' + nixpkgs.lib.concatStringsSep "\n"
              (map (s: ''(add-to-list 'exec-path "${s}/bin")'') all-packages);
            extraPackages = lisp-packages;
            bundledPackages = false;
            emacsPackages = pkgs.emacsPackagesFor emacs;
            emacsPackagesOverlay = self: super: {
              ox-chameleon = mkTrivialPkg {
                pkgs = self;
                name = "ox-chameleon";
                buildInputs = with self; [ engrave-faces ];
              };
              copilot = (mkTrivialPkg {
                pkgs = self;
                name = "copilot";
                buildInputs = with self; [ dash editorconfig s ];
                extraFiles = [ "dist/" ];
              });
              evil-collection = super.evil-collection.overrideAttrs
                (_: { src = inputs.evil-collection; });
              consult =
                super.consult.overrideAttrs (_: { src = inputs.consult; });
            };
          };
        in pkgs.callPackage nix-doom-emacs doom-emacs;
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      f = system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ emacs-overlay.overlay ];
          };
        in rec {
          devShells.${system}.default =
            pkgs.mkShell { buildInputs = [ (doom-emacs system pkgs) ]; };
          packages.${system}.default =
            (doom-emacs system pkgs).overrideAttrs (old: { pname = "emacs"; });
          overlay = self: super: { emacs = packages.${self.system}.default; };
        };
    in nixpkgs.lib.foldr nixpkgs.lib.recursiveUpdate { } (map f systems);
}
