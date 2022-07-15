PATCHWORK := patchwork

all:
	@echo "Available make targets:"
	@echo
	@echo "    patchwork     : build and install tool: patchwork"
	@echo "    export-patches: export patches to patches/ directory."
	@echo "    apply-patches : apply patches to tree in another workdir"

.PHONY: all

util/patchwork:
	make -C util

.PHONY: util/patchwork

patchwork: util/patchwork
	@cp $< $@

export-patches: patchwork
	@./patchwork export-patches

apply-patches: patchwork
	@if test -z $(repo); then \
  		echo "need provide repo argument"; \
  		exit 128; \
  	fi
	@./patchwork apply-patches --apply-to $(repo)

clean:
	@rm -rf patchwork
	@rm -rf util/patchwork
