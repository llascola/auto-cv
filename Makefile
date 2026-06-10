NAME=LucianoScolaCV

# Default: build with Tectonic (single static binary, reproducible, matches CI).
all:
	tectonic ${NAME}.tex

# Fallback for environments that still have a full TeXLive + latexmk.
latexmk:
	latexmk -pdf ${NAME}.tex

# Bilingual spell-check (needs aspell + English and Spanish dictionaries).
spell:
	bash scripts/spellcheck.sh ${NAME}.tex

clean:
	rm -f ${NAME}.aux ${NAME}.bbl ${NAME}.bcf ${NAME}.fdb_latexmk ${NAME}.fls ${NAME}.log ${NAME}.out ${NAME}.run.xml ${NAME}.blg ${NAME}.toc *\~

distclean: clean
	rm -f ${NAME}.pdf

.PHONY: all latexmk spell clean distclean
