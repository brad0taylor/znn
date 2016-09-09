# znn
Repository for neural network engines for Zynq FPGAs
Contact mail.brad.taylor at gmail 
This respository holds working files for a neural bet engine in Xilinx FPGAs. 
This is not stable 
The sysgen .slx file inplements a 4-line buffer and a 3x3 8-bit convolution engine. 
This is the start of an open source project involving Zynq FPGAs running DNNs using Python and Keras. It will initially target the Pynq board under development.  


Device Targets
 Zynq 7020.

Performance Targets
  350 MHz = ~6 GOPs per convolution engine

Density Targets (in 7020)
  110 8-bit convolvers 
  220 4-bit convolvers   

IP
The 4:2 compressor is from Martin Kumm of Kassel. It is key to the design as it reduces the adder tree LUTs by a factor of 3

Issues
 The SRAM is not mapping to simple dual port
 The adder tree is not using the 4:2 compressor due to simulink crash in
 Develop layer controller
 Develop weight unpacker
 Develop 
 
Next steps
  layer controller
  dense layer 
  activation layer
  stochastic rounding
  weight unpacker
  DDR buffer interface
  video and audio ports
  port squeeze or other DNNs to this engine

