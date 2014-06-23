# A list of all the verilog modules to be included in the build
MODULES := encoder scrambler

# Overridable if any of these tools are not in PATH
GTKWAVE  ?= gtkwave
IVERILOG ?= iverilog
VVP 	 ?= vvp

# Preserve some intermediate files made by implicit rules
.SECONDARY: $(MODULES:%=%.vvp)

# Declare phony targets
.PHONY: all test clean $(MODULES) $(MODULES:%=%-waveform)

# Rules
all: $(MODULES:%=%.vvp)

test: $(MODULES)

$(MODULES): %: %.vcd

$(MODULES:%=%-waveform): %-waveform: %.vcd
	$(GTKWAVE) $< $(wildcard $(patsubst %-waveform,%.gtkw,$@)) > /dev/null 2>&1 &

clean:
	-$(RM) $(MODULES:%=%.vcd) $(MODULES:%=%.vvp)

%.vcd: %.vvp
	$(VVP) $<

%.vvp: %_tb.v %.v
	$(IVERILOG) -t vvp -o $@ $^

