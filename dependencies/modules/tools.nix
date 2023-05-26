pkgs:
with pkgs;
[
  # debugger & copilot.el if it's enabled
  nodejs

  # debugger
  lldb

  # direnv
  direnv

  # lookup
  ripgrep
  wordnet

  # make
  gnumake
] ++ (lib.optional (!stdenv.isDarwin) gdb)
