{
  description = "nix-doom-emacs shell";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    nix-doom-emacs = {
      url = "github:nix-community/nix-doom-emacs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.emacs-overlay.follows = "emacs-overlay";
      inputs.flake-utils.follows = "flake-utils";
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
          all-packages = lisp-packages ++ (with pkgs;
            [
              ## basic dependencies
              emacs-all-the-icons-fonts
              bashInteractive
              binutils
              curlFull
              fd
              gitFull # handled by programs.git
              gnutls
              imagemagick
              pinentry-emacs
              (ripgrep.override { withPCRE2 = true; })
              wget
              zstd

              ## modules
              ### make
              gnumake

              ### lsp & copilot if it's enabled
              nodejs

              ### debugger
              lldb

              ### nix
              nixfmt
              nixUnstable

              ### org+roam and lookup
              sqlite
              wordnet

              ### ox-latex
              (with texlive;
                texlive.combine {
                  inherit scheme-small biblatex latexmk;
                  inherit capt-of siunitx wrapfig xcolor;
                })

              ### org+...
              graphviz
              xclip

              ### python
              (python3.withPackages
                (ps: with ps; [ black isort pip virtualenv ]))

              ### sh
              shellcheck
              shfmt

              ### spell
              (aspellWithDicts
                (dicts: with dicts; [ en en-computers en-science ]))

              ### rust
              cargo
              rustc
              rustfmt
              rust-analyzer
            ] ++ (if pkgs.stdenv.isDarwin then
              [ coreutils-prefixed ]
            else
              [ gdb ]));
          doom-emacs = nix-doom-emacs.packages.${system}.default.override rec {
            doomPrivateDir = pkgs.runCommand "doomPrivateDir" { } ''
              mkdir -p $out
              cp -r ${./.}/. $out
              cd $out

              ${emacs}/bin/emacs --batch -Q \
                --visit config.org \
                --eval "(require 'org)" \
                --funcall org-babel-tangle \
                --kill
            '';
            doomPackageDir = pkgs.runCommand "doomPackageDir" { } ''
              mkdir -p $out
              cd $out
              cp -r ${doomPrivateDir}/. $out
              chmod +w $out/config.el
              echo "" > $out/config.el
            '';
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
            };
          };
        in pkgs.symlinkJoin {
          name = "emacs";
          paths = [ doom-emacs ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/emacs \
                --suffix PATH $out/bin:${pkgs.lib.makeBinPath all-packages}
          '';
        };
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
    in nixpkgs.lib.foldr nixpkgs.lib.mergeAttrs { } (map f systems);
}
