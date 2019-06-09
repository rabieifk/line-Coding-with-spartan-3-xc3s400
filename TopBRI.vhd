--------------------------------------------------------------------------------
-- Copyright (c) 1995-2013 Xilinx, Inc.  All rights reserved.
--------------------------------------------------------------------------------
--   ____  ____ 
--  /   /\/   / 
-- /___/  \  /    Vendor: Xilinx 
-- \   \   \/     Version : 14.7
--  \   \         Application : sch2hdl
--  /   /         Filename : TOP_BRI.vhf
-- /___/   /\     Timestamp : 09/25/2016 18:46:01
-- \   \  /  \ 
--  \___\/\___\ 
--
--Command: sch2hdl -sympath D:/PRJ/Levon_BRI/FPGA/FPGA19_MultiComp/ipcore_dir -intstyle ise -family spartan3 -flat -suppress -vhdl D:/PRJ/Levon_BRI/FPGA/FPGA19_MultiComp/TOP_BRI.vhf -w D:/PRJ/Levon_BRI/FPGA/FPGA19_MultiComp/TOP_BRI.sch
--Design Name: TOP_BRI
--Device: spartan3
--Purpose:
--    This vhdl netlist is translated from an ECS schematic. It can be 
--    synthesized and simulated, but it should not be modified. 
--


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

use ieee.numeric_std.ALL;
library UNISIM;
use UNISIM.Vcomponents.ALL;

entity TOP_BRI is
	generic(
				CHAN_N:integer:=4;
				LED_N:integer:=10
			);
   port ( BIT_H      : in    std_logic_vector (CHAN_N*2-1 downto 0); 
          BIT_L      : in    std_logic_vector (CHAN_N*2-1 downto 0); 
          clk_pin    : in    std_logic; 
          clk_out_pin: out   std_logic; 
          reset_pin  : in    std_logic; 
          bitSigInd_o   : out   STD_LOGIC_VECTOR (2 downto 0); 
          spi_mosi_i : in    std_logic; 
          spi_sck_i  : in    std_logic; 
          spi_ssel_i : in    std_logic; 
--          PWM_VREF,PWM_VREF2   : out   STD_LOGIC;
          PWM_VREF   : out   std_logic_vector (CHAN_N-1 downto 0);		---STD_LOGIC;
          led_o   : out   STD_LOGIC_VECTOR (LED_N-1 downto 0); 
          FPGA_ADR   : in   STD_LOGIC_VECTOR (2 downto 0); 
--          FPGA_CNT   : in   STD_LOGIC_VECTOR (5 downto 0); 
          spi_miso_o : out   std_logic);
end TOP_BRI;

architecture BEHAVIORAL of TOP_BRI is
   attribute BOX_TYPE   : string ;
   signal clk_cnt    : std_logic_vector (10 downto 0);
   signal clk_out_stat, spi_sck_sig        : std_logic;
   signal clk,clk2x_sig  : std_logic;
   signal di         : std_logic_vector (15 downto 0);
   signal di_req     : std_logic;
   signal do         : std_logic_vector (15 downto 0);
   signal do_valid   : std_logic;
   signal reset      : std_logic;
   signal wren       : std_logic;
	signal spi_ssel_sig: std_logic;
	signal spi_miso_sig: std_logic;
--   signal XLXN_21    : std_logic;
--   signal XLXN_26    : std_logic;
	COMPONENT DCM1
	PORT(
		CLKIN_IN : IN std_logic;
		RST_IN : IN std_logic;          
		CLKIN_IBUFG_OUT : OUT std_logic;
		CLK0_OUT : OUT std_logic;
		CLK2X_OUT : OUT std_logic
		);
	END COMPONENT;
   
   component spi_slave
      port ( clk_i         : in    std_logic; 
             spi_ssel_i    : in    std_logic; 
             spi_sck_i     : in    std_logic; 
             spi_mosi_i    : in    std_logic; 
             wren_i        : in    std_logic; 
             di_i          : in    std_logic_vector (15 downto 0); 
             spi_miso_o    : out   std_logic; 
             di_req_o      : out   std_logic; 
             wr_ack_o      : out   std_logic; 
             do_valid_o    : out   std_logic; 
             do_transfer_o : out   std_logic; 
             wren_o        : out   std_logic; 
             rx_bit_next_o : out   std_logic; 
             do_o          : out   std_logic_vector (15 downto 0); 
             state_dbg_o   : out   std_logic_vector (3 downto 0); 
             sh_reg_dbg_o  : out   std_logic_vector (15 downto 0));
   end component;
   
--   component AND2
--      port ( I0 : in    std_logic; 
--             I1 : in    std_logic; 
--             O  : out   std_logic);
--   end component;
--   attribute BOX_TYPE of AND2 : component is "BLACK_BOX";
   
   component NAND2
      port ( I0 : in    std_logic; 
             I1 : in    std_logic; 
             O  : out   std_logic);
   end component;
   attribute BOX_TYPE of NAND2 : component is "BLACK_BOX";
   
   component channelFIFO
		generic (
			CHAN_N:integer;
			LED_N:integer
		);
      port ( clk        : in    std_logic; 
             reset      : in    std_logic; 
             di_req_i   : in    std_logic; 
             do_valid_i : in    std_logic; 
             BIT_H      : in    std_logic_vector (CHAN_N*2-1 downto 0); 
             BIT_L      : in    std_logic_vector (CHAN_N*2-1 downto 0); 
				 bitSigInd_o   : out   STD_LOGIC_VECTOR (2 downto 0); 
             do_i       : in    std_logic_vector (15 downto 0); 
             wren_o     : out   std_logic; 
--             PWM_VREF,PWM_VREF2   : out   STD_LOGIC;
             PWM_VREF   : out   std_logic_vector (CHAN_N-1 downto 0);	---STD_LOGIC;
             led_o   : out   STD_LOGIC_VECTOR (LED_N-1 downto 0); 
--	          FPGA_ADR   : in   STD_LOGIC_VECTOR (2 downto 0); 
--				 FPGA_CNT   : in   STD_LOGIC_VECTOR (5 downto 0); 
--             PWM_VREF,PWM_VREF2   : out   std_logic_vector (CHAN_N-1 downto 0); 
             di_o       : out   std_logic_vector (15 downto 0));
   end component;
   
begin
	process (clk)
	begin
		if rising_edge(clk2x_sig) then
			spi_sck_sig<=spi_sck_i;
		end if;--clk
		
		if rising_edge(clk) then
			clk_cnt<=clk_cnt+1;
			if(clk_cnt>=4) then		--conv_std_logic_vector(256,11)
				clk_cnt<=(others=>'0');
				clk_out_stat<=not clk_out_stat;
				clk_out_pin<=clk_out_stat;
			end if;
		end if;--clk
	end process;

--	Inst_DCM1: DCM1 PORT MAP(
--		CLKIN_IN => ,
--		RST_IN => ,
--		CLKIN_IBUFG_OUT => ,
--		CLK0_OUT => ,
--		CLK2X_OUT => 
--	);
--	clk<=clk_pin;
   DCM1_inst : DCM1
      port map (CLKIN_IN=>clk_pin,
                RST_IN=>reset,
                CLKIN_IBUFG_OUT=>open,
                CLK0_OUT=>clk,
                CLK2X_OUT=>clk2x_sig
                --LOCKED_OUT=>XLXN_21
					 );
   
	spi_ssel_sig<=spi_ssel_i;-- when (FPGA_CNT(2 downto 0)=FPGA_ADR(2 downto 0))
		--else ('1');
   
	spi_miso_o<=spi_miso_sig;-- when (FPGA_CNT(2 downto 0)=FPGA_ADR(2 downto 0))
		--else ('Z');
   
	spi_slave_inst : spi_slave
      port map (clk_i=>clk,
                di_i(15 downto 0)=>di(15 downto 0),
                spi_mosi_i=>spi_mosi_i,
                spi_sck_i=>spi_sck_sig,
                spi_ssel_i=>spi_ssel_sig,
                wren_i=>wren,
                di_req_o=>di_req,
                do_o(15 downto 0)=>do(15 downto 0),
                do_transfer_o=>open,
                do_valid_o=>do_valid,
                rx_bit_next_o=>open,
                sh_reg_dbg_o=>open,
                spi_miso_o=>spi_miso_sig,
                state_dbg_o=>open,
                wren_o=>open,
                wr_ack_o=>open);
   
--   XLXI_12 : AND2
--      port map (I0=>XLXN_26,
--                I1=>XLXN_21,
--                O=>clk);
   
   XLXI_26 : NAND2
      port map (I0=>reset_pin,
                I1=>reset_pin,
                O=>reset);
   
   channelFIFO_inst : channelFIFO
		generic map (
			CHAN_N => CHAN_N,
			LED_N => LED_N
		)
      port map (BIT_H=>BIT_H,
                BIT_L=>BIT_L,
					 bitSigInd_o=>bitSigInd_o,
                clk=>clk,
                di_req_i=>di_req,
                do_i(15 downto 0)=>do(15 downto 0),
                do_valid_i=>do_valid,
                reset=>reset,
					 PWM_VREF=>PWM_VREF,
--					 PWM_VREF2=>PWM_VREF2,
					 led_o=>led_o,
--					 FPGA_ADR=>FPGA_ADR, 
--					 FPGA_CNT=>FPGA_CNT,
                di_o(15 downto 0)=>di(15 downto 0),
                wren_o=>wren);
   
end BEHAVIORAL;


