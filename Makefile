## Basic Makefile for developing and debugging D projects.
## Production Makefile would likely have all the debugging stuff removed.

## WHAT YOU NEED TO CARE ABOUT:

# - Implicit rules for compiling D programs. `make foo' will work if there
# 	is a `foo.d' in the current directory; `make foo.o' will do the same.
#   They both pass object file dependencies to the linker as well.
# - Implicit rule for generating interface files. `make foo.di' will work if
#   there is a `foo.d' in the current directory.
# - Implicit rule for generating static libraries. `libfoo: bar.o baz.o' will
#   generate a static library containing the two object files.
# - Implicit rule for generating HTML D documentation from source files.
#   `make foo.html' will work if there is a `foo.d' in the current
#   directory.
# - Sane default `clean' operation, including deletion of all generated
#   object files, executables, libraries, interface files, and documentation.
# - Target for unit testing. `make test_foo' will compile and run unit tests
#   for `foo.d'. Note that `foo.d' must not have a main function defined.

DC = dmd
DFLAGS = -dw -m64 -w -wi -debug -Incurses -L-lncurses
DTESTFLAGS := $(DFLAGS) -unittest -main -run
ARGS = 

VPATH = src

# For working with literate programming.
TANGLE = notangle
WEAVE = noweave
TANGLEFORMAT = -L'// %L "%F"%N'
TANGLEFLAGS := -Rmain $(TANGLEFORMAT)
WEAVEFLAGS = -delay
WEAVEBEG = noweb/begin.noweb
WEAVEEND = noweb/end.noweb

## Options for deperecated flag
# -de   --    Do not allow deperecated features
# -d	--	  Silently allow
# -dw	--	  Allow and warn

all: keikai

test:
	$(TANGLE) -Rtest-driver $(TANGLEFORMAT) src/keikai.d.noweb > keikai_test.d
	$(DC) $(DTESTFLAGS) keikai_test.d

# Targets marked as prerequisites of .PHONY will always be run,
# even when there is a file with the same name.
.PHONY: clean

clean:
	@-rm -f *.d
	@-rm -f *.o
	@-rm -f *.a
	@-rm -f *.di
	@-rm -f *.out
	@-rm -f *.html
	@-rm -f *.aux
	@-rm -f *.pdf
	@-rm -f *.tex
	@-rm -f *.log
	@-find . -maxdepth 1 -type f -perm +111 -delete

run_%: %
	@./$< $(ARGS)

run_%: %.d
	@$(DC) $(DFLAGS) $<
	@./$* $(ARGS)

# Defaults.

lib%: 
	$(DC) $(DFLAGS) -lib -oflib$* $^

%: %.d
	$(DC) $(DFLAGS) $^

%: %.o
	$(DC) $(DFLAGS) $^

%.di: %.d
	$(DC) -H $<

%.o: %.d
	$(DC) -c $(DFLAGS) $<

%.html: %.d
	$(DC) -D -c $<

test_%: %.d
	@$(DC) $(DTESTFLAGS) $<
	@printf "All tests passed.\n"

## Rules for weaving/untangling code and documentation from NOWEB source.

%.d: %.d.noweb
	$(TANGLE) $(TANGLEFLAGS) $^ > $@

%.tex: %.d.noweb
	$(WEAVE) $(WEAVEFLAGS) $(WEAVEBEG) $^ $(WEAVEEND) > $@
