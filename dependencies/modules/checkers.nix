pkgs:
with pkgs; [
  # grammar
  languagetool

  # spell
  (aspellWithDicts (dicts: with dicts; [ en en-computers en-science ]))
]
