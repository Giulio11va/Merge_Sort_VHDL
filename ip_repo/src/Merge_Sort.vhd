library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Merge_Sort is
	generic (
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32;
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
		C_M_START_COUNT	: integer	:= 64
	);
	port (

		clk	: in std_logic;
		reset	: in std_logic;
		merge_stream_in	: in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
		S_AXIS_TLAST	: in std_logic;
		S_AXIS_TVALID	: in std_logic;
        rd_en : out std_logic;
        wr_en : out std_logic;
		merge_stream_out	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
		M_AXIS_TREADY	: in std_logic
		
	);
end Merge_Sort;

architecture arch_imp of Merge_Sort is


constant NUMBER_OF_INPUT_WORDS  : integer := 32;
constant NUMBER_OF_OUTPUT_WORDS : integer := 32;                                   


type customtype is array (integer range<>) of std_logic_vector(31 DOWNTO 0);
signal sipo: customtype(NUMBER_OF_INPUT_WORDS-1 downto 0);
signal sort2: customtype(NUMBER_OF_INPUT_WORDS-1 downto 0);
signal sort2q: customtype(NUMBER_OF_INPUT_WORDS-1 downto 0);
signal sort4: customtype(NUMBER_OF_INPUT_WORDS-1 downto 0);
signal sort4q: customtype(NUMBER_OF_INPUT_WORDS-1 downto 0);
signal sort8: customtype(NUMBER_OF_INPUT_WORDS-1 downto 0);
signal sort8q: customtype(NUMBER_OF_INPUT_WORDS-1 downto 0);
signal sort16: customtype(NUMBER_OF_INPUT_WORDS-1 downto 0);
signal sort16q: customtype(NUMBER_OF_INPUT_WORDS-1 downto 0);                   
signal sort32: customtype(NUMBER_OF_INPUT_WORDS-1 downto 0);
signal sort32q: customtype(NUMBER_OF_INPUT_WORDS-1 downto 0);


signal start_conversion : std_logic := '0';
signal shift : std_logic;
signal counter_conversion : integer := 0;
signal wren : std_logic := '0';
signal output_merge : std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);  



component reg is
  Port ( 
    clk: in std_logic;
    reset: in std_logic;
    d: in std_logic_vector(31 downto 0);
    q: out std_logic_vector(31 downto 0)
  );
end component;


	begin
	
Process(clk, reset)
	begin
	if rising_edge(clk) then
	
	if(S_AXIS_TLAST ='1') then
	   start_conversion <= '1';
	end if;
	
	end if;
	end process;
	
----------------------------------------------------------------------------------------------------------------------------------------------		 
--SIPO GENERATIONS
	SIPO_GEN : for i in 0 to NUMBER_OF_INPUT_WORDS-1 generate 

  SIPO_if_init : if i = 0 generate

    Register_init: reg
        Port Map(
            clk => clk,
            reset => reset,
            d => merge_stream_in,
            q => sipo(i)
        );
    end generate;

  SIPO_if_other : if i /= 0 generate

    Register_others : reg
        Port Map(
            clk => clk,
            reset => reset,
            d => sipo(i-1),
            q => sipo(i)
        );
    end generate;
 end generate;
	

	Process(clk, reset)
	begin
		
		if reset='1' then

		else 
			if rising_edge(clk) then
				
				if start_conversion = '1' then
					if counter_conversion >= 10 then
						shift <= '0';
					else
						shift <= '1';
						counter_conversion <= counter_conversion + 1;
					end if;
				end if;
				end if;
			end if;
			
	end process;
-----------------------------------------------------------------------------------------------------------------------------------------------------------
--MERGE-SORT ALGORITHM
	Cond2:Process(reset,S_AXIS_TLAST)
 begin
 
     if reset='1' then
     sort2<=(Others=>(Others=>'0'));
     
     elsif(rising_edge(S_AXIS_TLAST)) then
        for i in 0 to (NUMBER_OF_INPUT_WORDS-1)/2 loop
            if  (to_integer(unsigned(sipo(2*i))))<(to_integer(unsigned(sipo(2*i+1)))) then
            sort2(2*i)<=sipo(2*i);
            sort2(2*i+1)<=sipo(2*i+1);
            else
            sort2(2*i)<=sipo(2*i+1);
            sort2(2*i+1)<=sipo(2*i);
            end if;
        end loop;
     end if;
     
   
 end process;

 Reg_Cond_2 : for i in 0 to NUMBER_OF_INPUT_WORDS-1 generate
        Register_Cond_2 : reg
        Port Map(
            clk => clk,
            reset => reset,
            d => sort2(i),
            q => sort2q(i)
        );
    end generate;
    
 Cond4:Process(reset,sort2q)
 variable a,b : integer;
 begin
     
     if reset='1' then
     sort4<=(Others=>(Others=>'0'));
     else
        for i in 0 to (NUMBER_OF_INPUT_WORDS-1)/4 loop--DIVIDE INPUT ARRAYS IN 32/4 SUB-ARRAYS
            a:=0;
            b:=0;
            for j in 0 to 3 loop--SORTING EACH OF THE 32/4 SUB ARRAYS
            --TO BETTER UNDERSTAND THIS IF START LOOKING THE LATEST TWO
            --WE FIND THE LOWER VALUE BETWEEN THE ONE ON POSITIONS 0 OF THE SUBARRAYS AND THE ONE IN POSITION 4 AND WE INCREMENT A COUNTER
            --THE NEXT FOR CYCLE WE WILL CHECK THE HIGHER OF THE PREVIOUS NUMBERS WITH THE ONE AFTER THE LOWER OF THE PREVIOUS ONE
            --WHEN ONE OF THE TWO COUNTERS REACHES THE VALUE OF HALF OF THE SUB-ARRAY WE CAN DIRECTLY PUT THE REMAINING NUMBERS AT THE OUTPUT (FIRST AND SECOND IF)
				if b>=2 then
					sort4(4*i+j)<=sort2q(4*i+j);
					--//b++;
				elsif a>=2 and j>=2 then
					sort4(4*i+j)<=sort2q(4*i+j-2);
					--//a++;
				elsif sort2q(4*i+j-a)<=sort2q(4*i+j+2-b) then
					sort4(4*i+j)<=sort2q(4*i+j-a);
					b:=b+1;
				elsif sort2q(4*i+j-a)>sort2q(4*i+j+2-b) then
					sort4(4*i+j)<=sort2q(4*i+j+2-b);
					a:=a+1;
				end if;
			end loop;
		end loop;
     end if;
 end process;
 
  Reg_Cond_4 : for i in 0 to NUMBER_OF_INPUT_WORDS-1 generate
        Register_Cond_4 : reg
        Port Map(
            clk => clk,
            reset => reset,
            d => sort4(i),
            q => sort4q(i)
        );
    end generate;
    
    
    
    
 Cond8:Process(sort4q,reset)
 variable a,b : integer;
 begin
     
     if reset='1' then
     sort8<=(Others=>(Others=>'0'));
     else
        for i in 0 to (NUMBER_OF_INPUT_WORDS-1)/8 loop
            a:=0;
            b:=0;
            for j in 0 to 7 loop
            
				if b>=4 and j>=4 then
					sort8(8*i+j)<=sort4q(8*i+j);
					
				elsif a>=4 and j>=4 then    --9fpi7
					sort8(8*i+j)<=sort4q(8*i+j-4);

				elsif sort4q(8*i+j-a)<=sort4q(8*i+j+4-b) then
					sort8(8*i+j)<=sort4q(8*i+j-a);
					b:=b+1;
					
				elsif sort4q(8*i+j-a)>sort4q(8*i+j+4-b) then
					sort8(8*i+j)<=sort4q(8*i+j+4-b);
					a:=a+1;
				end if;
				
			end loop;
		end loop;
     end if;
 end process;
 
  Reg_Cond_8 : for i in 0 to NUMBER_OF_INPUT_WORDS-1 generate
        Register_Cond_8 : reg
        Port Map(
            clk => clk,
            reset => reset,
            d => sort8(i),
            q => sort8q(i)
        );
    end generate;
    
 Cond16:Process(sort8q,reset)
 variable a,b : integer;
 begin
     
     if reset='1' then
     sort16<=(Others=>(Others=>'0'));
     else
        for i in 0 to (NUMBER_OF_INPUT_WORDS-1)/16 loop
            a:=0;
            b:=0;
            for j in 0 to 15 loop
            
				if b>=8 and j>=8 then
					sort16(16*i+j)<=sort8q(16*i+j);
					
				elsif a>=8 and j>=8 then    
					sort16(16*i+j)<=sort8q(16*i+j-8);

				elsif sort8q(16*i+j-a)<=sort8q(16*i+j+8-b) then
					sort16(16*i+j)<=sort8q(16*i+j-a);
					b:=b+1;
					
				elsif sort8q(16*i+j-a)>sort8q(16*i+j+8-b) then
					sort16(16*i+j)<=sort8q(16*i+j+8-b);
					a:=a+1;
				end if;
				
			end loop;
		end loop;
     end if;
 end process;
 
  Reg_Cond_16 : for i in 0 to NUMBER_OF_INPUT_WORDS-1 generate
        Register_Cond_16 : reg
        Port Map(
            clk => clk,
            reset => reset,
            d => sort16(i),
            q => sort16q(i)
        );
    end generate;
    
    
    
 Cond32:Process(sort16q,reset)
 variable a,b : integer;
 begin
     
     if reset='1' then
     sort32<=(Others=>(Others=>'0'));
     else
        for i in 0 to (NUMBER_OF_INPUT_WORDS-1)/32 loop
            a:=0;
            b:=0;
            for j in 0 to 31 loop
            
				if b>=16 and j>=16 then
					sort32(32*i+j)<=sort16q(32*i+j);
					
				elsif a>=16 and j>=16 then    
					sort32(32*i+j)<=sort16q(32*i+j-16);

				elsif sort16q(32*i+j-a)<=sort16q(32*i+j+16-b) then
					sort32(32*i+j)<=sort16q(32*i+j-a);
					b:=b+1;
					
				elsif sort16q(32*i+j-a)>sort16q(32*i+j+16-b) then
					sort32(32*i+j)<=sort16q(32*i+j+16-b);
					a:=a+1;
				end if;
				
			end loop;
		end loop;
     end if;
 end process;
 
  Reg_Cond_32 : for i in 0 to NUMBER_OF_INPUT_WORDS-1 generate
        Register_Cond_32 : reg
        Port Map(
            clk => clk,
            reset => reset,
            d => sort32(i),
            q => sort32q(i)
        );
    end generate;
------------------------------------------------------------------------------------------------------------------------------------------------------------
--PISO PROCESS
	process (clk, reset, shift, sort32q) is 

	variable piso : customtype(NUMBER_OF_INPUT_WORDS-1 downto 0);

	begin

		if (reset='1') then
			piso := (others=>(Others => '0'));
		elsif (shift='1') then 
		    piso := sort32q;
			wren <= '0';
		elsif (rising_edge(clk) and M_AXIS_TREADY = '1') then 
			output_merge <= piso(NUMBER_OF_INPUT_WORDS-1);
			wren <= '1';
			piso := piso(NUMBER_OF_INPUT_WORDS-2 downto 0) & "00000000000000000000000000000000";
		end if;
		
	end process;
	
    
	
	wr_en <= wren;
	rd_en <= S_AXIS_TVALID;
	merge_stream_out <= output_merge; 


end arch_imp;
