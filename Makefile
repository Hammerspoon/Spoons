ZIPDIR=Spoons
SRCDIR=Source
ZIP=/usr/bin/zip

clean:
	rm -f $(ZIPDIR)/*.zip

$(ZIPDIR)/%.zip: 
	rm -f $@
	$(ZIP) -9 -r $@ $(SRCDIR)/$<
