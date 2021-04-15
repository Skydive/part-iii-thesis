(TeX-add-style-hook
 "main"
 (lambda ()
   (TeX-add-to-alist 'LaTeX-provided-class-options
                     '(("report" "a4paper" "9pt")))
   (TeX-run-style-hooks
    "latex2e"
    "titlepage"
    "declaration"
    "abstract"
    "report"
    "rep10"
    "epsfig"
    "graphicx"
    "verbatim"
    "parskip"
    "tabularx"
    "setspace"
    "xspace"
    "booktabs"
    "amsmath"
    "amssymb"
    "tikz")
   (TeX-add-symbols
    "authorname"
    "authorcollege"
    "authoremail"
    "dissertationtitle"
    "wordcount"))
 :latex)

