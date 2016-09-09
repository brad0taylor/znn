library ieee;
use ieee.std_logic_1164.all;

entity multibit_compressor_4_2 is
  generic(
    input_word_size  : integer := 10;
    subtract_y       : boolean := false;
    subtract_z       : boolean := false;
    use_output_ff    : boolean := true;
    is_signed        : boolean := true
  );
  port(
    clk_i   : in  std_logic;
    rst_i   : in  std_logic;
    w_i     : in  std_logic_vector((input_word_size - 1) downto 0);
    x_i     : in  std_logic_vector((input_word_size - 1) downto 0);
    y_i     : in  std_logic_vector((input_word_size - 1) downto 0);
    z_i     : in  std_logic_vector((input_word_size - 1) downto 0);
    sum_o   : out std_logic_vector(input_word_size downto 0);
    c_o     : out std_logic_vector(input_word_size downto 0)
  );
end entity;

architecture behavior of multibit_compressor_4_2 is
  
  -- this function calculates the initial carry bit for the carry chain
  function cc_init
    return std_logic is
    variable result : std_logic;
  begin
    result  := '0';
    
    if subtract_y and subtract_z then
      result  := '1';
    end if;
    
    return result;
  end function;
  
  component slice_setup
  	generic(
  		input_word_size				: integer	:= 4;
  		use_output_ff		: boolean	:= false;
  		is_initial_slice	: boolean	:= true;
  		subtract_y	: boolean	:= false;
  		subtract_z	: boolean	:= false
  	);
  	port(
  		-- signals for a synchronous circuit
  		clock				: in std_logic;
  		clock_enable	: in std_logic;
  		clear				: in std_logic;
  		w_i			: in	std_logic_vector((input_word_size - 1) downto 0);
  		x_i				: in	std_logic_vector((input_word_size - 1) downto 0);
  		y_i				: in	std_logic_vector((input_word_size - 1) downto 0);
  		z_i				: in	std_logic_vector((input_word_size - 1) downto 0);
  		carry_chain_i			: in	std_logic;
  		carry_chain_o		: out	std_logic;
  		sum_out			: out	std_logic_vector((input_word_size - 1) downto 0);
  		carry_o			: out	std_logic_vector((input_word_size - 1) downto 0)
  	);
  end component;  
  
  -- calculate the needed number of slices
  constant num_slices : integer := (input_word_size / 4) + 1;
  
  -- defines the initial carry values
  constant carry_cc   : std_logic := cc_init;
  
  signal carry  : std_logic_vector((num_slices - 1) downto 0);

  -- the input addends with sign extention
  signal w,x,y,z      : std_logic_vector((input_word_size) downto 0);

begin
	
  -- adding two bit sign extention to the input addends
  extention_signed: if is_signed = true generate
    w <= w_i(input_word_size - 1) & w_i;
    x <= x_i(input_word_size - 1) & x_i;
    y <= y_i(input_word_size - 1) & y_i;
    z <= z_i(input_word_size - 1) & z_i;
  end generate;
  
  extention_unsigned: if is_signed = false generate
    w <= '0' & w_i;
    x <= '0' & x_i;
    y <= '0' & y_i;
    z <= '0' & z_i;
  end generate;
	
  -- checking the parameter input_word_size
  assert (input_word_size > 0) report "an adder with a bit width of "
    & integer'image(input_word_size) & " is not possible." severity failure;
  
  -- generating the slice setups
  -- getting all signals into one slice
  single_slice: if num_slices = 1 generate
    slice_i: slice_setup
        generic map(
          input_word_size        => input_word_size,
          use_output_ff    => use_output_ff,
          is_initial_slice  => true,
          subtract_y  => subtract_y,
          subtract_z  => subtract_z
        )
        port map(
          clock       => clk_i,
          clock_enable  => '1',
          clear       => rst_i,
          w_i     => w, --bbus(input_word_size + 1 downto 0),
          x_i        => x,
          y_i        => y,
          z_i        => z,
          -- scrolling carry_o one position up
          carry_o      => c_o, --bbus(input_word_size + 2 downto 1),
          carry_chain_i      => carry_cc,
          carry_chain_o   => carry(0),
          sum_out     => sum_o
        );
  end generate;
  
  -- make more slices to calculate all signals
  multiple_slices: if num_slices > 1 generate
    slices: for i in 0 to (num_slices - 1) generate
      -- generate the first slice
      first_slice: if i = 0 generate
        slice_i: slice_setup
          generic map(
            input_word_size        => 4,
            use_output_ff    => use_output_ff,
            is_initial_slice  => true,
            subtract_y  => subtract_y,
            subtract_z  => subtract_z
          )
          port map(
            clock       => clk_i,
            clock_enable  => '1',
            clear       => rst_i,
            w_i        => w(3 downto 0), --bbus(3 downto 0),
            x_i        => x(3 downto 0),
            y_i        => y(3 downto 0),
            z_i        => z(3 downto 0),
            -- scrolling carry_o one position upwards
            carry_o      => c_o(3 downto 0), --bbus(4 downto 1),
            carry_chain_i      => carry_cc,
            carry_chain_o   => carry(0),
            sum_out     => sum_o(3 downto 0)
          );
      end generate;
      
      -- generate all full slices
      full_slice: if i > 0 and i < (num_slices - 1) generate
        slice_i: slice_setup
          generic map(
            input_word_size        => 4,
            use_output_ff    => use_output_ff,
            is_initial_slice  => false,
            subtract_y  => subtract_y,
            subtract_z  => subtract_z
          )
          port map(
            clock       => clk_i,
            clock_enable  => '1',
            clear       => rst_i,
            w_i        => w((4 * i) + 3 downto 4 * i), --bbus((4 * i) + 3 downto 4 * i),
            x_i        => x((4 * i) + 3 downto 4 * i),
            y_i        => y((4 * i) + 3 downto 4 * i),
            z_i        => z((4 * i) + 3 downto 4 * i),
            -- scrolling carry_o one position upwards
            carry_o      => c_o((4 * i) + 3 downto 4 * i), --bbus((4 * i) + 4 downto (4 * i) + 1),
            carry_chain_i      => carry(i - 1),
            carry_chain_o   => carry(i),
            sum_out     => sum_o((4 * i) + 3 downto 4 * i)
          );
      end generate;
      
      -- generate the last slice
      last_slice: if i = (num_slices - 1) generate
        slice_i: slice_setup
          generic map(
            input_word_size        => input_word_size+1 - (i * 4),
            use_output_ff    => use_output_ff,
            is_initial_slice  => false,
            subtract_y  => subtract_y,
            subtract_z  => subtract_z
          )
          port map(
            clock       => clk_i,
            clock_enable  => '1',   
            clear       => rst_i,
            w_i        => w(input_word_size downto 4 * i), --bbus(input_word_size + 1 downto 4 * i),
            x_i        => x(input_word_size downto 4 * i),
            y_i        => y(input_word_size downto 4 * i),
            z_i        => z(input_word_size downto 4 * i),
            -- scrolling carry_o one position up
            carry_o      => c_o(input_word_size downto 4 * i), --bbus(input_word_size + 2 downto (4 * i) + 1),
            carry_chain_i      => carry(i - 1),
            carry_chain_o   => carry(i),
            sum_out     => sum_o(input_word_size downto 4 * i)
          );
      end generate;
    end generate;
  end generate;
end architecture;

--- Definition of the slice_setup component which configures a single slice ---

library unisim;
use unisim.vcomponents.all;				-- loading xilinx primitives

library ieee;
use ieee.std_logic_1164.all;				-- loading std_logic & std_logic_vector

entity slice_setup is
	generic(
		input_word_size				: integer	:= 4;
		use_output_ff		: boolean	:= false;
		is_initial_slice	: boolean	:= true;
		subtract_y	: boolean	:= false;
		subtract_z	: boolean	:= false
	);
	port(
		-- signals for a synchronous circuit
		clock				: in std_logic;
		clock_enable	: in std_logic;
		clear				: in std_logic;
		w_i			: in	std_logic_vector((input_word_size - 1) downto 0);
		x_i				: in	std_logic_vector((input_word_size - 1) downto 0);
		y_i				: in	std_logic_vector((input_word_size - 1) downto 0);
		z_i				: in	std_logic_vector((input_word_size - 1) downto 0);
		carry_chain_i			: in	std_logic;
		carry_chain_o		: out	std_logic;
		sum_out			: out	std_logic_vector((input_word_size - 1) downto 0);
		carry_o			: out	std_logic_vector((input_word_size - 1) downto 0)
	);
end entity;

architecture behavior of slice_setup is
	-- this function returns the lut initialization
	function get_lut_init
		return bit_vector is
		-- defines several lut configurations
		-- for init calculation see "initializing_primitives.ods"
		constant lut_init_no_sub	: bit_vector(63 downto 0)	:= x"3cc3c33cfcc0fcc0";
		constant lut_init_sub_y		: bit_vector(63 downto 0)	:= x"c33c3cc3cf0ccf0c";
		constant lut_init_sub_z		: bit_vector(63 downto 0)	:= x"c33c3cc3f330f330";
		constant lut_init_sub_yz	: bit_vector(63 downto 0)	:= x"3cc3c33c3f033f03";
		variable curr_lut				  : bit_vector(63 downto 0)	:= lut_init_no_sub;
	begin
		curr_lut	:= lut_init_no_sub;
		
		if subtract_y then
			curr_lut	:= lut_init_sub_y;
		end if;
		
		if subtract_z then
			curr_lut	:= lut_init_sub_z;
		end if;
		
		if subtract_y and subtract_z then
			curr_lut	:= lut_init_sub_yz;
		end if;
		
		return curr_lut;
	end function;
	
	-- calculate how many bits to fill up with zeros for the carry chain
	constant fillup_width	: integer := 4 - input_word_size;
	
	-- holds the lut configuration used in this slice
	constant current_lut_init	: bit_vector := get_lut_init;
	
	-- output o6 of the luts
	signal lut_o6	: std_logic_vector((input_word_size - 1) downto 0);
	signal lut_o5	: std_logic_vector((input_word_size - 1) downto 0);

	-- the signals for and from the carry chain have to be wrapped into signals
	-- with a width of four, to fill them up with zeros and prevent synthesis
	-- warnings when doing this in the port map of the carry chain
	-- input di of the carry chain (have to be four bits width)
	signal cc_di	: std_logic_vector(3 downto 0);
	-- input s of the carry chain (have to be four bits width)
	signal cc_s		: std_logic_vector(3 downto 0);
	-- output o of the carry chain (have to be four bits width)
	signal cc_o		: std_logic_vector(3 downto 0);
	-- output co of the carry chain (have to be four bits width)
	signal cc_co	: std_logic_vector(3 downto 0);
		
begin
	-- check the generic parameter
	assert (input_word_size > 0 and input_word_size < 5) report "a slice with a bit width of "
		& integer'image(input_word_size) & " is not possible." severity failure;
	
	-- prepairing singals for the carry chain
	full_slice_assignment: if input_word_size = 4 generate
		cc_di	<= w_i;
		cc_s	<= lut_o6;
	end generate;
	
	last_slice_assignment: if input_word_size < 4 generate
		cc_di	<= (fillup_width downto 1 => '0') & w_i;
		cc_s	<= (fillup_width downto 1 => '0') & lut_o6;
	end generate;
	
	-- creating the lookup tables
	luts: for i in 0 to (input_word_size - 1) generate
		-- lut6_2 primitive is described in virtex 6 user guide on page 215:
		-- http://www.xilinx.com/support/documentation/sw_manuals/xilinx12_3/virtex6_hdl.pdf
		lut_bit_i: lut6_2
			generic map(
				init	=> current_lut_init
			)
			-------------------------------------------------------------------
			-- table of names and connections
			-- user guide				us 7,274,211				usage in adder
			-- ----------				------------				--------------
			-- i0							in1							gnd
			-- i1							in2							z(n)
			-- i2							in3							y(n)
			-- i3							in4							x(n)
			-- i4							in5							bbus(n-1)
			-- i5							in6							vdd
			-- o5							o5
			-- o6							o6
			-------------------------------------------------------------------
			port map(
				i0	=> '0',
				i1	=> z_i(i),
				i2	=> y_i(i),
				i3	=> x_i(i),
				i4	=> w_i(i),
				i5	=> '1',
				o5	=> lut_o5(i),
				o6 => lut_o6(i)
			);
	end generate;
	
	-- creating the carry chain
	-- carry4 primitive is described in virtex 6 user guide on page 108:
	-- http://www.xilinx.com/support/documentation/sw_manuals/xilinx12_3/virtex6_hdl.pdf
	initial_slice: if is_initial_slice = true generate
		init_cc: carry4
			-------------------------------------------------------------------
			-- table of names and connections
			-- user guide				usage in adder
			-- ----------				--------------
			-- co							msb is carry out, rest is not connected
			-- o							sum
			-- ci							in the initial slice: not connected
			-- cyinit					in the initial slice: add / ~sub
			-- di							bbus(n-1)
			-- s							lut_o6(n)
			-------------------------------------------------------------------
			port map(
				co			=> cc_co,
				o			=> cc_o,
				cyinit	=> '0',
				ci	=> carry_chain_i,
				di			=> cc_di,
				s			=> cc_s
			);
	end generate;
	
	further_slice: if is_initial_slice = false generate
		further_cc: carry4
			-------------------------------------------------------------------
			-- table of names and connections
			-- user guide				usage in adder
			-- ----------				--------------
			-- co							msb is carry out, rest is not connected
			-- o							sum
			-- ci							carry from previous slice
			-- cyinit					in further slices: not connected
			-- di							bbus(n-1)
			-- s							lut_o6(n)
			-------------------------------------------------------------------
			port map(
				co			=> cc_co,
				o			=> cc_o,
				cyinit	=> '0',
				ci	=> carry_chain_i,
				di			=> cc_di,
				s			=> cc_s
			);
	end generate;
	
	-- connect the last used output of the carry chain to the slice output
	carry_chain_o	<= cc_co(input_word_size - 1);
	
	-- creating the flip flops
	sum_register: if use_output_ff = true generate
		ffs: for i in 0 to (input_word_size - 1) generate
			ff_s: fdce
				generic map(
					-- initialize all flip flops with '0'
					init => '0'
				)
				-------------------------------------------------------------------
				-- table of names and connections
				-- user guide				usage in adder
				-- ----------				--------------
				-- clr						clear
				-- ce							clock_enable, always '1'
				-- d							cc_o
				-- c							clock
				-- q							sum(n)
				-------------------------------------------------------------------
				port map(
					clr	=> clear,
					ce		=> clock_enable,
					d		=> cc_o(i),
					c		=> clock,
					q		=> sum_out(i)
				);
			ff_c: fdce
				generic map(
					-- initialize all flip flops with '0'
					init => '0'
				)
				-------------------------------------------------------------------
				-- table of names and connections
				-- user guide				usage in adder
				-- ----------				--------------
				-- clr						clear
				-- ce							clock_enable, always '1'
				-- d							cc_o
				-- c							clock
				-- q							sum(n)
				-------------------------------------------------------------------
				port map(
					clr	=> clear,
					ce		=> clock_enable,
					d		=> lut_o5(i),
					c		=> clock,
					q		=> carry_o(i)
				);
		end generate;
	end generate;
	
	-- bypassing the flip flops in case of a asynchronous circuit
	bypass: if use_output_ff = false generate
		sum_out <= cc_o(input_word_size - 1 downto 0);
		carry_o <= lut_o5;
	end generate;
end architecture;
