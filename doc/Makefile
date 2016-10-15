# The afm files of texlive 2015 changes naming strategy and contains no Times-Roman.afm which is searched by ebnf2ps
EBNF_ENV=AFMPATH=~/others/fonts/afm/ RGBPATH=/opt/X11/share/X11
FONT=Helvetica
FONT_SCALE=12
DIM=1000

all: \
	figures/rule.svg \
	figures/target.svg \
	figures/target_list.svg \
	figures/lexpr.svg \
	figures/rexpr.svg \
	figures/ltoken.svg \
	figures/rtoken.svg \
	figures/word.svg \
	figures/protocol.svg


figures/%.eps : syntax.ebnf
	$(EBNF_ENV) ebnf2ps \
		-borderDistX $(DIM) -borderDistY $(DIM) \
		-tScale $(FONT_SCALE) -ntScale $(FONT_SCALE) -titleScale 15 \
		-lineWidth 80 -arrowSize 300 \
		-tFont "$(FONT)" -ntFont "$(FONT)" \
		-tBg "Gold" -ntBg "Cornsilk" \
		$^ $*
	mv $*.eps $@

figures/%.pdf : figures/%.eps
	epstopdf $< -o $@

figures/%.svg : figures/%.pdf
	pdf2svg $< $@
