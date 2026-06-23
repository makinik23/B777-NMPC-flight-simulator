THESIS_DIR := docs/thesis
ROOT_PDF := B777_NMPC_Flight_Simulator.pdf

.PHONY: all thesis pdf test clean clean-generated

all: thesis

thesis pdf:
	$(MAKE) -C $(THESIS_DIR) all

test:
	@echo "Run in MATLAB:"
	@echo "  startup"
	@echo "  results = run_feature_tests();"

clean:
	$(MAKE) -C $(THESIS_DIR) clean

clean-generated:
	rm -rf data/aerodynamics/raw/datcom/runs
	rm -f $(ROOT_PDF)
