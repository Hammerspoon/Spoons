ZIPDIR=Spoons
SRCDIR=Source
SOURCES := $(wildcard $(SRCDIR)/*.spoon)
SPOONS := $(addprefix $(ZIPDIR)/,$(notdir $(addsuffix .zip,$(SOURCES))))
ZIP=/usr/bin/zip

all: $(SPOONS)

clean:
	rm -f $(ZIPDIR)/*.zip

$(ZIPDIR)/%.zip: 
	rm -f $@
	$(ZIP) -9 -r $@ $(SRCDIR)/$<

.PHONY: clean
