MAIN := main
PROJECT_ROOT := ../..
ROOT_PDF := B777_NMPC_Flight_Simulator.pdf

.PHONY: all clean cleanall

all:
	pdflatex $(MAIN).tex
	biber $(MAIN)
	pdflatex $(MAIN).tex
	pdflatex $(MAIN).tex
	cp $(MAIN).pdf $(PROJECT_ROOT)/$(ROOT_PDF)
	rm -f $(MAIN).pdf

clean:
	rm -f *.aux *.bbl *.bcf *.blg *.log *.out *.run.xml *.toc *.lof *.lot *.fls *.fdb_latexmk

cleanall: clean
	rm -f $(MAIN).pdf $(PROJECT_ROOT)/$(ROOT_PDF)
