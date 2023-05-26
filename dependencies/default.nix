pkgs:
with pkgs;
let
  import' = with builtins;
    path:
    map (n: import (path + ("/" + n)) pkgs) (filter (n:
      match ".*\\.nix" n != null
      || pathExists (path + ("/" + n + "/default.nix")))
      (attrNames (readDir path)));
in [
  emacs-all-the-icons-fonts
  bashInteractive
  binutils
  curlFull
  fd
  gitFull
  gnutls
  imagemagick
  pinentry-emacs
  (ripgrep.override { withPCRE2 = true; })
  wget
  zstd.bin
  zstd
] ++ lib.optional (!stdenv.isLinux) coreutils-prefixed
++ lib.lists.flatten (import' ./modules)
