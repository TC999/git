PATCHWORK := patchwork

all: export-patches

patchwork: clean
	@make -C util
	@cp util/patchwork .

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