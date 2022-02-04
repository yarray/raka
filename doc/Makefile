# this will also generate all svgs
all: syntax.md

# use grammkit to generate svgs, install via npm install grammkit
# it is a W3C ebnf file (https://www.w3.org/TR/2004/REC-xml11-20040204/#sec-notation), not in ISO ebnf format (with massive comma and outdated)
syntax.md: syntax.ebnf
	grammkit -f ebnf -t md $<