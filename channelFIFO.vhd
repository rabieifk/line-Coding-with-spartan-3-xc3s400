library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
package my_types_pkg is
  type array8 is array (natural range <>) of std_logic_vector(7 downto 0);
end package;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use work.my_types_pkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity channelFIFO is
	generic(
				CHAN_N:integer;
				LED_N:integer;
				DECODER_MODE_PANA:integer:=0;
				DECODER_MODE_ERIC:integer:=1;
				DECODER_MODE_ALCA:integer:=2;
				FIFO_IP_DATA_CNT_W:integer:=11;
				FIFO_IP_D_DATA_CNT_W:integer:=7;
--				chanel_active_level:integer:=15000;
				HDLC_N:integer:=2;
				--FRAME_W:integer:=36;
				SPI_W:integer:=16;
				--FIFO_W:integer:=36;
				CMD_W:integer:=8
			);
    Port (
           clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
			  BIT_H      : in    STD_LOGIC_VECTOR (CHAN_N*2-1 downto 0);
           BIT_L      : in    STD_LOGIC_VECTOR (CHAN_N*2-1 downto 0);
           bitSigInd_o   : out   STD_LOGIC_VECTOR (2 downto 0); 
--           PWM_VREF,PWM_VREF2   : out   STD_LOGIC;
           PWM_VREF   : out   STD_LOGIC_VECTOR (CHAN_N-1 downto 0); 		--STD_LOGIC;
           led_o   : out   STD_LOGIC_VECTOR (LED_N-1 downto 0); 
--			  FPGA_ADR   : in   STD_LOGIC_VECTOR (2 downto 0); 
--           FPGA_CNT   : in   STD_LOGIC_VECTOR (5 downto 0); 
--           PWM_VREF   : out   STD_LOGIC_VECTOR (CHAN_N-1 downto 0); 
--           frame_ready_i, TE_i : in  STD_LOGIC;
--           frameIn : in  STD_LOGIC_VECTOR (FRAME_W-1 downto 0);
--			  superFrameNum_i: in STD_LOGIC_VECTOR (1 downto 0);
			  ------spi interface
--      PARALLEL WRITE PIPELINED SEQUENCE
--      =================================
			  di_req_i : in  STD_LOGIC;
			  di_o : out  STD_LOGIC_VECTOR (SPI_W-1 downto 0);
			  wren_o : out STD_LOGIC;
--      PARALLEL READ PIPELINED SEQUENCE
--      ================================
			  do_i : in  STD_LOGIC_VECTOR (SPI_W-1 downto 0);
			  do_valid_i : in  STD_LOGIC
			  );
end channelFIFO;

architecture Behavioral of channelFIFO is

function reverse_any_vector (a: in std_logic_vector)
return std_logic_vector is
  variable result: std_logic_vector(a'RANGE);
  alias aa: std_logic_vector(a'REVERSE_RANGE) is a;
begin
  for i in aa'RANGE loop
    result(i) := aa(i);
  end loop;
  return result;
end; -- function reverse_any_vector

-- The following code must appear in the VHDL architecture header:

------------- Begin Cut here for COMPONENT Declaration ------ COMP_TAG
COMPONENT FIFO_IP
  PORT (
    clk : IN STD_LOGIC;
    --rst : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    full : OUT STD_LOGIC;
    overflow : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    valid : OUT STD_LOGIC;
    underflow : OUT STD_LOGIC;
    data_count : OUT STD_LOGIC_VECTOR(FIFO_IP_DATA_CNT_W-1 DOWNTO 0)
  );
END COMPONENT;

COMPONENT FIFO_IP_D
  PORT (
    clk : IN STD_LOGIC;
    --srst : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    data_count : OUT STD_LOGIC_VECTOR(FIFO_IP_D_DATA_CNT_W-1 DOWNTO 0)--6
  );
END COMPONENT;

component UpSignalDecoder
	port ( 
			clk             : in    std_logic; 
			reset           : in    std_logic;
			decoder_mode_sel_i:in	STD_LOGIC_VECTOR (2 downto 0);
			BIT_L_1x,BIT_L_2x  : in    std_logic; 
			BIT_H_1x,BIT_H_2x  : in    std_logic; 
			bitSigInd_o   : out   STD_LOGIC_VECTOR (2 downto 0); 
--			PWM_VREF        : out   std_logic; 
			frame_ready_o   : out   std_logic; 
--			TE_o            : out   std_logic; 
			frameOut0, frameOut1 : out  STD_LOGIC_VECTOR (15 downto 0);
			HDLC_ready_o : out  STD_LOGIC_VECTOR (HDLC_N-1 downto 0);
			HDLC_Out : out array8(HDLC_N-1 downto 0)		--out  STD_LOGIC_VECTOR (7 downto 0)
--       superFrameNum_o : out   std_logic_vector (1 downto 0)
	);
end component;


type VecArr_bitSigInd IS ARRAY (CHAN_N-1 DOWNTO 0) OF STD_LOGIC_VECTOR(2 downto 0);
signal bitSigInd : VecArr_bitSigInd;

--type vector16 is array (natural range <>) of std_logic_vector(15 downto 0);
--signal v_normal_in_sig : vector16(7 downto 0);
--type buff10 IS ARRAY (1 DOWNTO 0) OF STD_LOGIC_VECTOR (Dat_wide DOWNTO 0);
subtype STD_LOGIC_VECTOR_CHAN IS std_logic_vector (CHAN_N-1 downto 0);
type VecArr8 IS ARRAY (CHAN_N-1 DOWNTO 0) OF STD_LOGIC_VECTOR(7 downto 0);
--type VecArr16 IS ARRAY (CHAN_N-1 DOWNTO 0) OF STD_LOGIC_VECTOR(15 downto 0);
type VecArrFIFODat IS ARRAY (CHAN_N-1 DOWNTO 0) OF STD_LOGIC_VECTOR(15 downto 0);


signal frameSig0,frameSig1      : VecArrFIFODat;		--std_logic_vector (FIFO_W-1 downto 0);
signal frame_ready   : STD_LOGIC_VECTOR_CHAN;


type VecArrFIFOCnt IS ARRAY (CHAN_N-1 DOWNTO 0) OF STD_LOGIC_VECTOR(FIFO_IP_DATA_CNT_W-1 downto 0);
-----fifo sig
signal fifo_rd_en0, fifo_rd_en1 : STD_LOGIC_VECTOR_CHAN;
signal fifo_dout0, fifo_dout1 : VecArrFIFODat;		--STD_LOGIC_VECTOR(FRAME_W-1 DOWNTO 0);
signal fifo_full0, fifo_full1 : STD_LOGIC_VECTOR_CHAN;
signal fifo_overflow0, fifo_overflow1 : STD_LOGIC_VECTOR_CHAN;
signal fifo_empty0, fifo_empty1 : STD_LOGIC_VECTOR_CHAN;
signal fifo_valid0, fifo_valid1 : STD_LOGIC_VECTOR_CHAN;
signal fifo_underflow0, fifo_underflow1 : STD_LOGIC_VECTOR_CHAN;
signal fifo_data_count0, fifo_data_count1 : VecArrFIFOCnt;		--STD_LOGIC_VECTOR(10 DOWNTO 0);
-----
signal chanel_active0, chanel_active1 : STD_LOGIC_VECTOR_CHAN;
--type VecArr16Bit IS ARRAY (CHAN_N-1 DOWNTO 0) OF STD_LOGIC_VECTOR(15 downto 0);
--signal chanel_active_cnt0, chanel_active_cnt1 : VecArr16Bit;--STD_LOGIC_VECTOR (CHAN_N-1 DOWNTO 0)(7 downto 0);---B1 B2 actvity cnt
signal frameOutFF0, frameOutFF1 : VecArrFIFODat;-- STD_LOGIC_VECTOR (CHAN_N-1 DOWNTO 0)(15 downto 0);---B1 B2 last data

type VecArrDFIFOCnt IS ARRAY (CHAN_N-1 DOWNTO 0) OF STD_LOGIC_VECTOR(FIFO_IP_D_DATA_CNT_W-1 downto 0);
signal HDLC_Out0,HDLC_Out1      : VecArr8;		--std_logic_vector (FIFO_W-1 downto 0);
signal HDLC_ready_o0, HDLC_ready_o1   : STD_LOGIC_VECTOR_CHAN;
signal Dfifo_rd_en0, Dfifo_rd_en1 : STD_LOGIC_VECTOR_CHAN;
signal Dfifo_dout0, Dfifo_dout1 : VecArr8;		--STD_LOGIC_VECTOR(FRAME_W-1 DOWNTO 0);
signal Dfifo_full0, Dfifo_full1 : STD_LOGIC_VECTOR_CHAN;
signal Dfifo_data_count0, Dfifo_data_count1 : VecArrDFIFOCnt;		--STD_LOGIC_VECTOR(10 DOWNTO 0);


--type CMD_TYPE is (CMD_NONE, CMD_GET_FIFO_CNT);
constant CMD_TEST:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(1, CMD_W);
constant CMD_GET_FIFO_CNT_B1:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(2, CMD_W);
constant CMD_GET_FIFO_DATA_B1:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(3, CMD_W);

constant CMD_GET_FIFO_CNT_B2:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(12, CMD_W);
constant CMD_GET_FIFO_DATA_B2:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(13, CMD_W);

constant CMD_GET_FIFO_CNT_D_TE:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(22, CMD_W);
constant CMD_GET_FIFO_DATA_D_TE:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(23, CMD_W);

constant CMD_GET_FIFO_CNT_D_LT:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(32, CMD_W);
constant CMD_GET_FIFO_DATA_D_LT:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(33, CMD_W);

---CMD_GET_CHAN_ACTIVITY0
constant CMD_GET_CHAN_ACTIVITY0:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(200, CMD_W);
constant CMD_GET_CHAN_ACTIVITY1:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(201, CMD_W);
--constant CMD_SET_PWM_VREF:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(205, CMD_W);
constant CMD_SET_PWM_VREF:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(220, CMD_W);---205
constant CMD_SET_PWM_VREF7:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(227, CMD_W);---205
constant CMD_SET_LED_STAT0:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(210, CMD_W);
constant CMD_SET_LED_STAT1:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(211, CMD_W);

constant CMD_SET_DECODER_MODE:STD_LOGIC_VECTOR(CMD_W-1 DOWNTO 0):=conv_std_logic_vector(215, CMD_W);

signal do_valid_i_ff : STD_LOGIC:='0';
signal decoder_mode_sel_sig : STD_LOGIC_VECTOR (2 downto 0):=(others=>'0');

signal cntPWM:STD_LOGIC_VECTOR (7 downto 0):=(others=>'0');--7
--signal valPWM:STD_LOGIC_VECTOR (7 downto 0):=(others=>'0');
signal valPWM:VecArr8;	---STD_LOGIC_VECTOR (7 downto 0):=(others=>'0');
signal ledStat:STD_LOGIC_VECTOR (15 downto 0):=(others=>'0');

begin


   frame_FIFO0: 
   for i in 0 to CHAN_N-1 generate
      frame_FIFO0 : FIFO_IP
		PORT MAP (
		 clk => clk,
		 --rst => reset,

		 din => frameSig0(i),
		 wr_en => frame_ready(i),
		 
		 rd_en => fifo_rd_en0(i),
		 dout => fifo_dout0(i),
		 full => fifo_full0(i),
		 overflow => fifo_overflow0(i),
		 empty => fifo_empty0(i),
		 valid => fifo_valid0(i),
		 underflow => fifo_underflow0(i),
		 data_count => fifo_data_count0(i)
		);
   end generate frame_FIFO0;

   frame_FIFO1:
   for i in 0 to CHAN_N-1 generate
      frame_FIFO1 : FIFO_IP
		PORT MAP (
		 clk => clk,
		 --rst => reset,

		 din => frameSig1(i),
		 wr_en => frame_ready(i),
		 
		 rd_en => fifo_rd_en1(i),
		 dout => fifo_dout1(i),
		 full => fifo_full1(i),
		 overflow => fifo_overflow1(i),
		 empty => fifo_empty1(i),
		 valid => fifo_valid1(i),
		 underflow => fifo_underflow1(i),
		 data_count => fifo_data_count1(i)
		);
   end generate frame_FIFO1;

   FIFO_IP_D_TE:
	for i in 0 to CHAN_N-1 generate
      FIFO_IP_D_TE : FIFO_IP_D
		PORT MAP (
		 clk => clk,
		 --srst => '0',--reset,

		 din => HDLC_Out0(i),
		 wr_en => HDLC_ready_o0(i),
		 
		 rd_en => Dfifo_rd_en0(i),
		 dout => Dfifo_dout0(i),
		 full => Dfifo_full0(i),
		 data_count => Dfifo_data_count0(i)
		);
   end generate FIFO_IP_D_TE;

   FIFO_IP_D_LT:
	for i in 0 to CHAN_N-1 generate
      FIFO_IP_D_LT : FIFO_IP_D
		PORT MAP (
		 clk => clk,
		 --srst => '0',--reset,

		 din => HDLC_Out1(i),
		 wr_en => HDLC_ready_o1(i),
		 
		 rd_en => Dfifo_rd_en1(i),
		 dout => Dfifo_dout1(i),
		 full => Dfifo_full1(i),
		 data_count => Dfifo_data_count1(i)
		);
   end generate FIFO_IP_D_LT;


	bitSigInd_o <= bitSigInd(0);

   UpSignalDecoderIns: 
   for i in 0 to CHAN_N-1 generate
      UpSignalDecoderIns : UpSignalDecoder
		PORT MAP (
			 clk=>clk,
			 reset=>reset,

			 bitSigInd_o=>bitSigInd(i),
			 
			 decoder_mode_sel_i=>decoder_mode_sel_sig,

			 BIT_H_1x=>BIT_H(i),
			 BIT_L_1x=>BIT_L(i),
			 BIT_H_2x=>BIT_H(i+4),
			 BIT_L_2x=>BIT_L(i+4),

--			 PWM_VREF=>PWM_VREF(i),

			 frameOut0=>frameSig0(i),
			 frameOut1=>frameSig1(i),
			 frame_ready_o=>frame_ready(i),
			 
			 HDLC_ready_o(0)=>HDLC_ready_o0(i),
			 HDLC_ready_o(1)=>HDLC_ready_o1(i),
			 HDLC_Out(0)=>HDLC_Out0(i),		-- : out array8(HDLC_N-1 downto 0)		--out  STD_LOGIC_VECTOR (7 downto 0)
			 HDLC_Out(1)=>HDLC_Out1(i)


--                superFrameNum_o(1 downto 0)=>superFrameNum(i)(1 downto 0),
--			 TE_o=>TE(i)
		 );
   end generate UpSignalDecoderIns;
   

	led_o(LED_N-1 downto 0)<=not ledStat(LED_N-1 downto 0);

	process (clk)
	variable cmd : STD_LOGIC_VECTOR(7 DOWNTO 0);
	variable cmdData : STD_LOGIC_VECTOR(7 DOWNTO 0);
	variable valPWM2:array8(CHAN_N-1 downto 0);		--STD_LOGIC_VECTOR (7 downto 0):=(others=>'0');
	
	begin
		if rising_edge(clk) then
			if(reset='1') then
				decoder_mode_sel_sig<=(others=>'0');
--				frame_ready_i_val<='0';
--				frame_FIFO_TE_rd<=(others=>'0');
--				frame_FIFO_LT_rd<=(others=>'0');
--				frame_FIFO_TE_wr<=(others=>'0');
--				frame_FIFO_LT_wr<=(others=>'0');
			else----not reset
						
			------chanel_active detector
			for i in 0 to CHAN_N-1 loop
				if(frame_ready(i)='1') then
					frameOutFF0(i)<=frameSig0(i);
					frameOutFF1(i)<=frameSig1(i);

					if(frameOutFF0(i)/=frameSig0(i)) then ---signal activity
--						if(chanel_active_cnt0(i)>chanel_active_level) then
							chanel_active0(i)<='1';
--						else
--							chanel_active_cnt0(i)<=chanel_active_cnt0(i)+8;
--						end if;
					else	---silence
--						if(chanel_active_cnt0(i)<=0) then
							chanel_active0(i)<='0';
--						else
--							chanel_active_cnt0(i)<=chanel_active_cnt0(i)-1;
--						end if;
					end if;

					if(frameOutFF1(i)/=frameSig1(i)) then ---signal activity
--						if(chanel_active_cnt1(i)>chanel_active_level) then
							chanel_active1(i)<='1';
--						else
--							chanel_active_cnt1(i)<=chanel_active_cnt1(i)+8;
--						end if;
					else	---silence

							chanel_active1(i)<='0';

					end if;
				end if;
			end loop;
			------
			
--			------PWM ref Generation
			cntPWM<=cntPWM+1;
			for i in 0 to CHAN_N-1 loop
				if(decoder_mode_sel_sig=DECODER_MODE_PANA) then
					valPWM2(i)(7):='0';
					valPWM2(i)(6 downto 0):=valPWM(i)(7 downto 1);
				elsif(decoder_mode_sel_sig=DECODER_MODE_ERIC or decoder_mode_sel_sig=DECODER_MODE_ALCA) then
					valPWM2(i)(7):='0';
					valPWM2(i)(6):='0';
					valPWM2(i)(5):='0';
					valPWM2(i)(4 downto 0):=valPWM(i)(7 downto 3);
				end if;
				------PWM Generation
				if(cntPWM<valPWM2(i)) then
					PWM_VREF(i)<='1';
				else
					PWM_VREF(i)<='0';
				end if;
			end loop;
			------
			
			wren_o<='0';
			fifo_rd_en0<=(others=>'0');
			fifo_rd_en1<=(others=>'0');
			Dfifo_rd_en0<=(others=>'0');
			Dfifo_rd_en1<=(others=>'0');
			do_valid_i_ff<=do_valid_i;
			if(do_valid_i='1' and do_valid_i_ff='0') then
				cmd:=do_i(SPI_W-1 downto 8);
				cmdData:=do_i(7 downto 0);
				case cmd is
					when (CMD_TEST) =>
						di_o<=cmdData&cmdData;
						wren_o<='1';
						
--					when (CMD_SET_PWM_VREF) =>
--						di_o<=(others=>'0');
--						wren_o<='1';
--						if(cmdData<30) then	---minimum reference voltage
--							valPWM<=conv_std_logic_vector(30,8);
--						else
--							valPWM<=cmdData;
--						end if;
					when CMD_SET_PWM_VREF | CMD_SET_PWM_VREF+1 | CMD_SET_PWM_VREF+2 | CMD_SET_PWM_VREF+3 | CMD_SET_PWM_VREF+4 | CMD_SET_PWM_VREF+5 | CMD_SET_PWM_VREF+6 | CMD_SET_PWM_VREF+7 =>
						di_o<=(others=>'0');
						wren_o<='1';
--						if(cmdData<100) then	---minimum reference voltage
--							valPWM<=conv_std_logic_vector(100,8);
--						else
							valPWM(conv_integer(cmd-CMD_SET_PWM_VREF))<=cmdData;
--						end if;
						
					when (CMD_SET_LED_STAT0) =>
						di_o<=(others=>'0');
						ledStat(7 downto 0)<=cmdData;
						wren_o<='1';
					when (CMD_SET_LED_STAT1) =>
						di_o<=(others=>'0');
						ledStat(15 downto 8)<=cmdData;
						wren_o<='1';
						
					---CMD_SET_DECODER_MODE
					when (CMD_SET_DECODER_MODE) =>
						di_o<=(others=>'0');
						decoder_mode_sel_sig<=cmdData(2 downto 0);
						wren_o<='1';
						
					when (CMD_GET_FIFO_CNT_B1) =>
						if(cmdData>CHAN_N-1) then
							di_o<=(others=>'0');
						else
							di_o<="000000" & fifo_data_count0(conv_integer(cmdData));
						end if;
						wren_o<='1';
						
					when (CMD_GET_FIFO_CNT_B2) =>
						if(cmdData>CHAN_N-1) then
							di_o<=(others=>'0');
						else
							di_o<="000000" & fifo_data_count1(conv_integer(cmdData));
						end if;
						wren_o<='1';
						
					when (CMD_GET_FIFO_CNT_D_TE) =>
						if(cmdData>CHAN_N-1) then
							di_o<=(others=>'0');
						else
							di_o<="000000000" & Dfifo_data_count0(conv_integer(cmdData));
						end if;
						wren_o<='1';

					when (CMD_GET_FIFO_CNT_D_LT) =>
						if(cmdData>CHAN_N-1) then
							di_o<=(others=>'0');
						else
							di_o<="000000000" & Dfifo_data_count1(conv_integer(cmdData));
						end if;
						wren_o<='1';

					when (CMD_GET_CHAN_ACTIVITY0) =>
						di_o<=chanel_active0;
						wren_o<='1';
					when (CMD_GET_CHAN_ACTIVITY1) =>
						di_o<=chanel_active1;
						wren_o<='1';

					when (CMD_GET_FIFO_DATA_B1) =>

						if(cmdData>CHAN_N-1) then
							di_o<=(others=>'0');
						else
							di_o<=reverse_any_vector(fifo_dout0(conv_integer(cmdData))(7+8 downto 0+8)) 
								& reverse_any_vector(fifo_dout0(conv_integer(cmdData))(7 downto 0));
							fifo_rd_en0(conv_integer(cmdData))<='1';
						end if;
						wren_o<='1';
						
					when (CMD_GET_FIFO_DATA_B2) =>
						if(cmdData>CHAN_N-1) then
							di_o<=(others=>'0');
						else
							di_o<=reverse_any_vector(fifo_dout1(conv_integer(cmdData))(7+8 downto 0+8)) 
								& reverse_any_vector(fifo_dout1(conv_integer(cmdData))(7 downto 0));
							fifo_rd_en1(conv_integer(cmdData))<='1';
						end if;
						wren_o<='1';
						
					when (CMD_GET_FIFO_DATA_D_TE) =>
						if(cmdData>CHAN_N-1) then
							di_o<=(others=>'0');
						else
							di_o<=reverse_any_vector(Dfifo_dout0(conv_integer(cmdData)));
							Dfifo_rd_en0(conv_integer(cmdData))<='1';
						end if;
						wren_o<='1';
						
					when (CMD_GET_FIFO_DATA_D_LT) =>
						if(cmdData>CHAN_N-1) then
							di_o<=(others=>'0');
						else
							di_o<=reverse_any_vector(Dfifo_dout1(conv_integer(cmdData)));
							Dfifo_rd_en1(conv_integer(cmdData))<='1';
						end if;
						wren_o<='1';
						
					when others =>
						di_o<=(others=>'0');
						wren_o<='1';
					
				end case;
			end if;
			
			end if;----not reset
		end if;--clk
	end process;

end Behavioral;

