DEVLIBDIR=~/src/dac_framework/libs

OUTDIR=.

all: $(OUTDIR)/XEM3010EndPoint.v

$(OUTDIR)/XEM3010EndPoint.v: sim.py
	PYTHONPATH=.:$(DEVLIBDIR):$(PYTHONPATH) python $(DEVLIBDIR)/devlib/di.py -v XEM3010 -o $(OUTDIR) sim 
	
