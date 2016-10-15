EBNF_ENV=AFMPATH=/System/Library/Frameworks/Python.framework/Versions/2.7/Extras/lib/python/matplotlib/mpl-data/fonts/pdfcorefonts/ RGBPATH=/opt/X11/share/X11
FONT_SIZE=13
DIM=800

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
		-tScale $(FONT_SIZE) -ntScale $(FONT_SIZE) -titleScale 15 \
		-lineWidth 80 -arrowSize 400 \
		-tBg "Gold" -ntBg "Cornsilk" \
		$^ $*
	cp $*.eps $@

figures/%.pdf : figures/%.eps
	epstopdf $< -o $@

figures/%.svg : figures/%.pdf
	pdf2svg $< $@
