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

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use work.my_types_pkg.all;

entity UpSignalDecoder is
	generic(
				USE_HDLC: boolean := false;
				DATA_SIMULATION: boolean := false;
				HDLC_N:integer:=2;
				DECODER_MODE_PANA:integer:=0;
				FRAME_W_PANA:integer:=27;
				FRAME_W_ERIC:integer:=36;
			);
    Port (
           clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
			  decoder_mode_sel_i : in STD_LOGIC_VECTOR (2 downto 0);
				BIT_L_1x,BIT_L_2x  : in    std_logic; 
				BIT_H_1x,BIT_H_2x  : in    std_logic; 
           bitSigInd_o   : out   STD_LOGIC_VECTOR (2 downto 0); 
           frame_ready_o : out  STD_LOGIC;
           frameOut0, frameOut1 : out  STD_LOGIC_VECTOR (15 downto 0);
			  HDLC_ready_o : out  STD_LOGIC_VECTOR (HDLC_N-1 downto 0);
           HDLC_Out : out array8(HDLC_N-1 downto 0)
			 );
end UpSignalDecoder;

architecture Behavioral of UpSignalDecoder is

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

TYPE sinTable_Type IS ARRAY (0 to 99) OF INTEGER;
constant sinTable:sinTable_Type:=
(
0,2057,4107,6140,8149,10126,12063,13952,15786,17558,19260,20887,22431,23886,
25248,26509,27667,28714,29649,30466,31164,31738,32187,32509,32703,32767,32703,32509,32187,
31738,31164,30466,29649,28714,27667,26509,25248,23886,22431,20887,19260,17558,15786,13952,
12063,10126,8149,6140,4107,2057,0,-2057,-4107,-6140,-8149,-10126,-12063,-13952,-15786,
-17558,-19260,-20887,-22431,-23886,-25248,-26509,-27667,-28714,-29649,-30466,-31164,-31738,-32187,-32509,
-32703,-32767,-32703,-32509,-32187,-31738,-31164,-30466,-29649,-28714,-27667,-26509,-25248,-23886,-22431,
-20887,-19260,-17558,-15786,-13952,-12063,-10126,-8149,-6140,-4107,-2057
);

--constant BIT_TH:integer:=30;	--10;--30
----constant BIT_MAX:integer:=15;--35
----constant BIT_SAMPLE_DELAY:integer:=20;
--constant ONE_BIT_IDX:integer:=200;---260=2.60us
--constant ONE_BIT_HYST:integer:=90;	--70;---2.60us
----constant GUARD_TIME:integer:=100;	--60;		---2;	--5
--constant RESERVE_TIME:integer:=ONE_BIT_IDX*5;	--60;		---2;	--5

---50Mhz
constant SCRAMBLER_W:integer:=9;
---PANA
constant BIT_TH_PANA:integer:=15;	--25;	--15;--30
constant ONE_BIT_IDX_PANA:integer:=100;---260=2.60us
constant ONE_BIT_HYST_PANA:integer:=47;	--35;	--70;---2.60us
constant RESERVE_TIME_PANA:integer:=ONE_BIT_IDX_PANA*5;	--60;		---2;	--5
---ERIC
----20us master to slave delay
----40us reserve time
constant BIT_TH_ERIC:integer:=15;	--10;--30
constant ONE_BIT_IDX_ERIC:integer:=130;---260=2.60us
constant ONE_BIT_HYST_ERIC:integer:=60;	--70;---2.60us
constant RESERVE_TIME_ERIC:integer:=ONE_BIT_IDX_ERIC*11;	--13=35us
-------Alcatel
constant BIT_TH_ALCA:integer:=3;	--10;--30
constant ONE_BIT_IDX_ALCA:integer:=28;---260=2.60us
constant ONE_BIT_HYST_ALCA:integer:=47;	--70;---2.60us
constant RESERVE_TIME_ALCA:integer:=ONE_BIT_IDX_ALCA*12;	--13=35us
-------
constant HDLC_BIT_POS0_ALCA:integer:=8;
constant HDLC_BIT_POS1_ALCA:integer:=9;

constant HDLC_BIT_POS0_PANA:integer:=8;
constant HDLC_BIT_POS1_PANA:integer:=9;

constant HDLC_BIT_POS0_ERIC:integer:=16;
constant HDLC_BIT_POS1_ERIC:integer:=17;
constant HDLC_BIT_POS2_ERIC:integer:=34;
constant HDLC_BIT_POS3_ERIC:integer:=35;

signal  HDLC_ready_FF : STD_LOGIC_VECTOR (HDLC_N-1 downto 0):=(others=>'0');
signal  doubleTransCnt : STD_LOGIC_VECTOR (1 downto 0):=(others=>'0');

type stat_type is ( WAIT_FOR_START_BIT_STAT, START_SAMPLING_STAT);
signal stat:stat_type:=WAIT_FOR_START_BIT_STAT;

type bit_val_type is (VAL_ZERO, VAL_N, VAL_L, VAL_H);
signal nextBitVal, lastBitVal:bit_val_type:=VAL_ZERO;

signal TE_stat, frame_ready, frame_ready_o_val, bitSigInd, bitSigInd2, frame_ready_n:STD_LOGIC:='0';
signal valL_FF, valH_FF: STD_LOGIC_VECTOR (3-1 downto 0):=(others=>'0');
--signal BIT_L, BIT_H:STD_LOGIC:='0';
signal valL:STD_LOGIC:='0';
signal cntL:STD_LOGIC_VECTOR (7 downto 0):=(others=>'0');
signal valH:STD_LOGIC:='0';
signal cntH:STD_LOGIC_VECTOR (7 downto 0):=(others=>'0');

signal bitSigInd_ff:STD_LOGIC:='0';

signal bitNum:STD_LOGIC_VECTOR (7 downto 0):=(others=>'0');
signal bitSamp:STD_LOGIC_VECTOR (15 downto 0):=(others=>'0');
signal delayCnt:STD_LOGIC_VECTOR (15 downto 0):=(others=>'0');

signal divTEST:STD_LOGIC_VECTOR (15 downto 0):=(others=>'0');
signal cntTEST:STD_LOGIC_VECTOR (7 downto 0):=(others=>'0');


signal descrambler_LFSR_TE:STD_LOGIC_VECTOR (SCRAMBLER_W-1 downto 0):=(others=>'0');--- linear-feedback shift register
signal descrambler_LFSR_LT:STD_LOGIC_VECTOR (SCRAMBLER_W-1 downto 0):=(others=>'0');--- linear-feedback shift register

signal frameWord,frameWord_FF,frameWord_FF_TE:STD_LOGIC_VECTOR (70-1 downto 0):=(others=>'0');		--40

subtype STD_LOGIC_VECTOR_CHAN_HDLC IS std_logic_vector (HDLC_N-1 downto 0);

-----micHDLC SIG
signal HDLC_FF:array8(HDLC_N-1 downto 0);--:=(others=>'0');
signal HDLC_CNT:array8(HDLC_N-1 downto 0);--:=(others=>'0');

--------HDLC SIG
signal    Rxclk_HDLC       :  STD_LOGIC_VECTOR_CHAN_HDLC;        -- Rx Clock
signal    Rx_HDLC          :  STD_LOGIC_VECTOR_CHAN_HDLC;        -- RX input serial data
--signal    RxData_HDLC      :  VecArr8;  -- Rx backedn Data bus
signal    ValidFrame_HDLC  :  STD_LOGIC_VECTOR_CHAN_HDLC;        -- Valid Frame
signal    FrameError_HDLC  :  STD_LOGIC_VECTOR_CHAN_HDLC;        -- Frame Error (Indicates error in the
                                        -- next byte at the backend
signal    AbortSignal_HDLC :  STD_LOGIC_VECTOR_CHAN_HDLC;        -- Abort signal
signal    Readbyte_HDLC    :  STD_LOGIC_VECTOR_CHAN_HDLC;        -- backend read byte
--signal    rdy_HDLC         :  STD_LOGIC_VECTOR_CHAN_HDLC;        -- backend ready signal
signal    RxEn_HDLC        :  STD_LOGIC_VECTOR_CHAN_HDLC;
signal    HDLC_ready_sig, HDLC_ready_sig_FF        :  STD_LOGIC_VECTOR_CHAN_HDLC;

---------

--component RxChannel_ent
--	port ( 
--			 Rxclk       : in  std_logic;        -- Rx Clock
--			 rst         : in  std_logic;        -- system reset
--			 Rx          : in  std_logic;        -- RX input serial data
--			 RxData      : out std_logic_vector(7 downto 0);  -- Rx backedn Data bus
--			 ValidFrame  : out std_logic;        -- Valid Frame
--			 FrameError  : out std_logic;        -- Frame Error (Indicates error in the
--															 -- next byte at the backend
--			 AbortSignal : out std_logic;        -- Abort signal
--			 Readbyte    : in  std_logic;        -- backend read byte
--			 rdy         : out std_logic;        -- backend ready signal
--			 RxEn        : in  std_logic
--		);
--end component;

begin
--	UseHDLC:if USE_HDLC generate
--		HDLC_Ins: 
--		for i in 0 to HDLC_N-1 generate
--			HDLC_Ins : RxChannel_ent
--			PORT MAP (
--				 rst=>not reset,
--
--				 Rxclk=>Rxclk_HDLC(i),
--				 Rx=>Rx_HDLC(i),
--				 RxData=>HDLC_Out(i),	--RxData_HDLC(i),
--				 ValidFrame=>ValidFrame_HDLC(i),
--				 FrameError=>FrameError_HDLC(i),
--				 AbortSignal=>AbortSignal_HDLC(i),
--				 Readbyte=>Readbyte_HDLC(i),
--				 rdy=>HDLC_ready_sig(i),	--rdy_HDLC(i),
--				 RxEn=>RxEn_HDLC(i)
--			 );
--		end generate HDLC_Ins;
--   end generate;
	
	process (clk)
		variable BIT_TH:integer;
		variable ONE_BIT_IDX:integer;
		variable ONE_BIT_HYST:integer;
		variable RESERVE_TIME:integer;

		variable valT, valT_HDLC:STD_LOGIC:='0';
		variable currentBitVal:bit_val_type:=VAL_ZERO;
	begin
		if(decoder_mode_sel_i=DECODER_MODE_PANA) then
			BIT_TH:=BIT_TH_PANA;
			ONE_BIT_IDX:=ONE_BIT_IDX_PANA;
			ONE_BIT_HYST:=ONE_BIT_HYST_PANA;
			RESERVE_TIME:=RESERVE_TIME_PANA;

		end if;
		
		if rising_edge(clk) then
			if(reset='1') then
				frame_ready_n<='0';
				frame_ready_o<='0';-- TE_o<='0';
				frameOut0<=(others=>'0');
				frameOut1<=(others=>'0');
				descrambler_LFSR_TE<=(others=>'0');
				descrambler_LFSR_LT<=(others=>'0');

				frameWord<=(others=>'0');
				stat<=WAIT_FOR_START_BIT_STAT;	--DELAY_START_BIT_STAT;

				valL_FF<="000"; valH_FF<="000"; TE_stat<='0'; frame_ready<='0'; frame_ready_o_val<='0';
				valL<='0';
				cntL<=(others=>'0');
				valH<='0';
				cntH<=(others=>'0');

				bitNum<=(others=>'0'); bitSamp<=(others=>'0');
				HDLC_FF(0)<=(others=>'0');
				HDLC_FF(1)<=(others=>'0');
				HDLC_CNT(0)<=(others=>'0');
				HDLC_CNT(1)<=(others=>'0');
				HDLC_ready_FF<=(others=>'0');
			else----not reset

			---------TEST
			if DATA_SIMULATION then
				divTEST<=divTEST+1;
				if(divTEST>=3125-1)then	--3125
					divTEST<=(others=>'0');
					if(TE_stat='1')then
						cntTEST<=cntTEST+1;---must be 3 to detect frame lost
						if(cntTEST>=99)then
							cntTEST<=(others=>'0');
						end if;
					end if;
--					frameWord(7+10 downto 0+10)<=reverse_any_vector(cntTEST);
--					frameWord(7+18 downto 0+18)<=reverse_any_vector(cntTEST);
					frameWord(7+10 downto 0+10)<=reverse_any_vector(conv_std_logic_vector(sinTable(conv_integer(cntTEST))+32768, 16)(15 downto 8));
					frameWord(7+18 downto 0+18)<=reverse_any_vector(conv_std_logic_vector(sinTable(conv_integer(cntTEST))+32768, 16)(15 downto 8));


					frame_ready<='1';
				end if;
			end if;
			---------TEST

--			------L bit detection
--			if(BIT_L='1' and valH='0') then
--				if(cntL<BIT_TH)then
--					cntL<=cntL+1;
--				else
--					valL<='1';
--				end if;
--			else
--				if(cntL>0)then
--					cntL<=cntL-1;
--				else
--					valL<='0';
--				end if;
--			end if;
--			
--			------H bit detection
--			if(BIT_H='1' and valL='0') then
--				if(cntH<BIT_TH)then
--					cntH<=cntH+1;
--				else
--					valH<='1';
--				end if;
--			else
--				if(cntH>0)then
--					cntH<=cntH-1;
--				else
--					valH<='0';
--				end if;
--			end if;

--			valL<=BIT_L;
--			valH<=BIT_H;


			valL<=BIT_L_1x;
			valH<=BIT_H_1x;
			
			--bitSigInd_o(0) <= valL;-- or valH;
			bitSigInd_o(1) <= valL or valH;

			--------HDLC
--			if USE_HDLC then
--				for i in 0 to HDLC_N-1 loop
--					Rxclk_HDLC(i)<='0';
--					RxEn_HDLC(i)<='1';
--					Readbyte_HDLC(i)<='0';
--					HDLC_ready_o(i)<=HDLC_ready_sig(i);
--					HDLC_ready_sig_FF(i)<=HDLC_ready_sig(i);
--					if(HDLC_ready_sig(i)='1' and HDLC_ready_sig_FF(i)='0') then
--						Readbyte_HDLC(i)<='1';
--					end if;
--				end loop;
--			else	--not USE_HDLC
				for i in 0 to HDLC_N-1 loop
					HDLC_ready_o(i)<='0';
					HDLC_ready_FF(i)<='0';
					if(HDLC_ready_FF(i)='1') then
						HDLC_CNT(i)<=(others=>'0');
						HDLC_Out(i)(7 downto 0)<=HDLC_FF(i)(7 downto 0);
						HDLC_FF(i)<=(others=>'0');
						HDLC_ready_o(i)<='1';
					end if;
				end loop;
--				if(HDLC_ready_FF(conv_integer(TE_stat))='1') then
--					--HDLC_ready_FF(conv_integer(TE_stat))<='0';
--					HDLC_CNT(conv_integer(TE_stat))<=(others=>'0');
--					HDLC_Out(conv_integer(TE_stat))(7 downto 0)<=HDLC_FF(conv_integer(TE_stat))(7 downto 0);
--					HDLC_FF(conv_integer(TE_stat))<=(others=>'0');
--					HDLC_ready_o(conv_integer(TE_stat))<='1';
--				end if;
--			end if;	---USE_HDLC
			--------

			bitSamp<=bitSamp+1;
			delayCnt<=delayCnt+1;

			valL_FF<=valL_FF(1 downto 0) & valL;
			valH_FF<=valH_FF(1 downto 0) & valH;
			if((valL_FF="011" or valH_FF="011")	--((valL='1' and valL_FF='0') or (valH='1' and valH_FF='0')
--					 and 
--					((valL='0' and valL_FF='1') or (valH='0' and valH_FF='1')))
					) then
				
				valL_FF<= "000";
				valH_FF<= "000";

				if(valL_FF="011") then	--valL='1' and valL_FF='0'
					lastBitVal<=VAL_L;
					currentBitVal:=VAL_L;
					
				else--if(valH='1') then
					lastBitVal<=VAL_H;
					currentBitVal:=VAL_H;
				end if;
				-------framing bit detection
				if (stat=WAIT_FOR_START_BIT_STAT and delayCnt>(ONE_BIT_IDX*2)) then--- or bitSamp>(ONE_BIT_IDX*2)   or (currentBitVal/=lastBitVal)  
					stat<=START_SAMPLING_STAT;
					--bitSigInd_o(0) <= '1';
					--frameWord(0)<='1';
					bitNum<=(others=>'0');---conv_std_logic_vector(1,8);--
					if(bitSamp>=RESERVE_TIME) then
						TE_stat<='0';
					end if;
					bitSamp<=(others=>'0');
--					if(valL='1') then
--						cvLastVal<=VAL_L;
--					elsif(valH='1') then
--						cvLastVal<=VAL_H;
--					end if;
				elsif (stat=START_SAMPLING_STAT and 
				((currentBitVal/=lastBitVal))) then-- or bitSamp>(ONE_BIT_IDX*2)
					if
						bitSamp<=(others=>'0');
						if(valL_FF="011") then	--valL='1'
							nextBitVal<=VAL_L;
						else--if() then	--valH='1'
							nextBitVal<=VAL_H;
						end if;
					end if;
				end if;
			end if;
			
			------state machine
--			if (stat=DELAY_START_BIT_STAT) then
--				if(bitSamp>=GUARD_TIME) then	--4	---Guard time (2 bits)	----+BIT_SAMPLE_DELAY*5
--					stat<=WAIT_FOR_START_BIT_STAT;
--				end if;
--			els



			-----frame transfer
			if(frame_ready='1' and frame_ready_o_val='0') then
				if(TE_stat='1') then
					frameWord_FF_TE<=frameWord;
					
					frame_ready_o<='1';
					frame_ready_o_val<='1';


					if(decoder_mode_sel_i=DECODER_MODE_PANA) then
						frameOut0(15 downto 0)<=frameWord(7+10 downto 0+10) & frameWord_FF(7+10 downto 0+10);---Master phone
						frameOut1(15 downto 0)<=frameWord(7+18 downto 0+18) & frameWord_FF(7+18 downto 0+18);---Slave phone

						frameWord<=(others=>'0');
						frame_ready<='0';
						TE_stat<=not TE_stat;
					else
						if(frame_ready_n='1') then
							frameOut0(15 downto 0)<="00101010" & frameWord_FF(7+18 downto 0+18);--frameWord_FF(7+18 downto 0+18);---Master phone
							frameOut1(15 downto 0)<="00101010" & frameWord_FF(7+26 downto 0+26);--frameWord_FF(7+26 downto 0+26);---Slave phone
							frame_ready_n<='0';
							
							frameWord<=(others=>'0');
							frame_ready<='0';
							TE_stat<=not TE_stat;
						else
							frameOut0(15 downto 0)<="00101010" & frameWord_FF(7+0 downto 0+0) ;--frameWord_FF(7+0 downto 0+0);---Master phone
							frameOut1(15 downto 0)<="00101010" & frameWord_FF(7+8 downto 0+8);--frameWord_FF(7+8 downto 0+8);---Slave phone
							frame_ready_n<='1';
							
--							if(--frameWord_FF(7+0 downto 0+0)="11010101" or 
--								--frameWord_FF(7+0 downto 0+0)="10101011" or 
--								--frameWord_FF(7+0 downto 0+0)="10101010" or
--								--frameWord_FF(7+0 downto 0+0)="01010101" or
--								frameWord_FF(7+0 downto 0+0)="01010100" or
--								frameWord_FF(7+0 downto 0+0)="00101010"
--								) then
--								bitSigInd_o(2) <= '1';
--							else
--								bitSigInd_o(2) <= '0';
--							end if;
						end if;
					end if;
				else	---not te stat
					frameWord_FF<=frameWord;
					
					frame_ready_n<='0';

					frameWord<=(others=>'0');
					frame_ready<='0';
					TE_stat<=not TE_stat;
				end if;
			end if;---end of frame_ready
			if(frame_ready_o_val='1') then
				frame_ready_o<='0';
				frame_ready_o_val<='0';
			end if;
			-----frame transfer end.
			
			
			end if;----not reset
		end if;--clk
	end process;--decoder
end Behavioral;

