DC = dmd
LIBS = -lncurses 
DFLAGS := $(addprefix -L,$(LIBS))

blah:
	echo "$(DFLAGS)"
