(TeX-add-style-hook
 "main"
 (lambda ()
   (TeX-add-to-alist 'LaTeX-provided-class-options
                     '(("report" "a4paper" "12pt")))
   (TeX-run-style-hooks
    "latex2e"
    "titlepage"
    "declaration"
    "abstract"
    "report"
    "rep12"
    "epsfig"
    "graphicx"
    "verbatim"
    "parskip"
    "tabularx"
    "setspace"
    "xspace")
   (TeX-add-symbols
    "authorname"
    "authorcollege"
    "authoremail"
    "dissertationtitle"
    "wordcount"))
 :latex)

