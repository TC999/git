PATCHWORK := patchwork

all:
	@echo "Available make targets:"
	@echo
	@echo "    patchwork     : build and install tool: patchwork"
	@echo "    export-patches: export patches to patches/ directory."
	@echo "    apply-patches : apply patches to tree in another workdir"

.PHONY: all

util/patchwork:
	@make -C util 2>/dev/null

.PHONY: util/patchwork

patchwork: util/patchwork
	@cp $< $@

export-patches: patchwork
	@rm -rf patches
	@./patchwork export-patches

define check_dest_envvar
	$(if $(DEST), \
                $(if $(filter ../% /%,$(DEST)), , \
			$(error DEST should be a directory outside current dir (start with "../" or "/"))), \
		$(error DEST is not defined))
endef

apply-patches: patchwork
	@$(check_dest_envvar)
	@if test -z $(DEST); then \
		echo >&2 "Error: no target repo dir is provided."; \
		echo >&2 "Please use: make apply-patches DEST=<target-dir>"; \
		exit 1; \
	elif ! test -d $(DEST); then \
		echo >&2 "Error: path \"$(DEST)\" not exist"; \
		exit 1; \
	fi
	@./patchwork apply-patches --apply-to $(DEST)

clean:
	@rm -rf patchwork
	@rm -rf util/patchwork
