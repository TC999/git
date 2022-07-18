SHELL_PATH ?= $(SHELL)
SHELL_PATH_SQ = $(subst ','\'',$(SHELL_PATH))
RM ?= rm -f
PROVE ?= prove
AGGREGATE_SCRIPT ?= lib/aggregate-results.sh
DEFAULT_TEST_TARGET ?= prove
TEST_OPTS ?= -v

T = $(sort $(wildcard t[0-9]*.sh))

all: $(DEFAULT_TEST_TARGET)

test: pre-clean
	@$(MAKE) -s --no-print-directory aggregate-results-and-cleanup

prove: pre-clean
	@echo "*** prove ***"; $(PROVE) --exec '$(SHELL_PATH_SQ)' $(PROVE_OPTS) $(T) :: $(TEST_OPTS)
	@$(MAKE) -s --no-print-directory clean-except-prove-cache

$(T):
	@echo "*** $@ ***"; '$(SHELL_PATH_SQ)' $@ $(TEST_OPTS)

pre-clean:
	$(RM) -r test-results

clean-except-prove-cache:
	$(RM) -r 'trash directory'.* test-results

clean: clean-except-prove-cache
	$(RM) .prove

aggregate-results-and-cleanup: $(T)
	@$(MAKE) -s --no-print-directory aggregate-results
	@$(MAKE) -s --no-print-directory clean

aggregate-results:
	for f in test-results/*.counts; do \
		echo "$$f"; \
	done | '$(SHELL_PATH_SQ)' '$(AGGREGATE_SCRIPT)'

.PHONY: all test prove $(T) pre-clean clean
.PHONY: aggregate-results-and-cleanup aggregate-results
