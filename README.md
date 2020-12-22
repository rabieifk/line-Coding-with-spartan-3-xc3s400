# line-Coding-with-spartan-3-xc3s400
**Objective:** Digital line decoding and produce the HDLC packet


Using spartan 3 xc3s400 FPGA to decode digital line

In this project line coding is done with spartan 3 familiy a xc3s400 and the code uses FIFO for storing data

There are four modules, first of all line is decoded by decoder module, then the result of decoding should be stored in some FIFOs and finally in the TOP module the connection is done by SPI and also a module for clock is used. 

The rate of the data is 8000 byte per second. A digital line consists some voice and signal packet. 

The HDLC packet is provided by FPGA and send to high level for processing.
