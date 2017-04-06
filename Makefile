ZIPDIR=Spoons
SRCDIR=Source
SOURCES := $(wildcard $(SRCDIR)/*.spoon)
SPOONS := $(patsubst $(SRCDIR)/%, $(ZIPDIR)/%.zip, $(SOURCES))
ZIP=/usr/bin/zip

all: $(SPOONS)

clean:
	rm -f $(ZIPDIR)/*.zip

$(ZIPDIR)/%.zip: $(SRCDIR)/%
	rm -f $@
	cd $(SRCDIR) ; $(ZIP) -9 -r ../$@ $(patsubst $(SRCDIR)/%, %, $<)

.PHONY: clean
