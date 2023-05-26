pkgs:
with pkgs;
[
  # C/C++
  bear
  clang
  cmake
  llvm

  # haskell
  (haskellPackages.ghcWithPackages (ps:
    with ps; [
      haskell-language-server
      hlint
      hoogle
      stack
      stylish-haskell
    ]))

  # nix
  nixfmt
  nixUnstable

  # python
  (python3.withPackages
    (ps: with ps; [ black debugpy isort pip pyflakes pyright virtualenv ]))

  # rust
  cargo
  rustc
  rustfmt
  rust-analyzer

  # sh
  shellcheck
  shfmt
] ++ lib.optional stdenv.isDarwin irony-server
