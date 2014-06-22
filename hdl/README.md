Adding a new module
===================

Every module must include a testbench along with the module
definition. If the module name is _encoder_ the module definition
should be named *encoder.v* and the corresponding testbench named
*encoder_tb.v*.

A new module can be added to the simulation system by adding the
module name to the MODULES list defined in Makefile.

Simulating a module
===================

If the module _encoder_ is in the MODULES list it can be simulated by
executing the make target with the same name:

```sh
make encoder
```

The waveforms can be viewed with GTKWave by executing the make target
with *-waveform* appended to the module name:

```sh
make encoder-waveform
```

If a GTKWave save file with the same name as the module (*encoder.gtkw*
for this example) exists in the same directory it will be also be
passed to GTKWave.
