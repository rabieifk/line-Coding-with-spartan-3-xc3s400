# line-Coding-with-spartan-3-xc3s400
**Objective:** Digital line decoding and produce the HDLC packet


Using spartan 3 xc3s400 FPGA to decode digital line

In this project line coding is done with spartan 3 familiy a xc3s400 and the code uses FIFO for storing data

There are four modules, first of all line is decoded by decoder module named [UpSignalDecoding](https://github.com/rabieifk/line-Coding-with-spartan-3-xc3s400/blob/master/UpSignalDecoder.vhd), then the result of decoding should be stored in some [FIFOs](https://github.com/rabieifk/line-Coding-with-spartan-3-xc3s400/blob/master/channelFIFO.vhd) and finally in the [TOP module](https://github.com/rabieifk/line-Coding-with-spartan-3-xc3s400/blob/master/TopBRI.vhd) the connection is done by [SPI](https://github.com/rabieifk/line-Coding-with-spartan-3-xc3s400/blob/master/spi_slave.vhd) and also a module for [clock](https://github.com/rabieifk/line-Coding-with-spartan-3-xc3s400/blob/master/DCM1.vhd) is used. 


The rate of the data is 8000 byte per second. A digital line consists some voice and signal packet as it is shown in [Burst Mode Timing on the Line](https://github.com/rabieifk/line-Coding-with-spartan-3-xc3s400/blob/master/Burst%20Mode%20Timing%20on%20the%20Line%20.png). 

The HDLC packet is provided by FPGA and send to high level for processing.
