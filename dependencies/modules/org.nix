  pkgs:
  with pkgs; [
    # roam
    sqlite
    wordnet

    # ox-latex
    (with texlive;
      texlive.combine {
        inherit scheme-small biblatex latexmk;
        inherit capt-of siunitx wrapfig xcolor;
      })

    # misc
    gnuplot
    graphviz
    xclip
  ]
