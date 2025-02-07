---------------------------------------------------------------------------------------------------------------------------
--
--  Conway's Game of Life Testbench
--
--  This file contains the testbench for Conway's Game of Life. In order to thoroughly test the Conway's Game of Life entity, 
--  this testbench uses features from OSVVM. The testbench is made to work with a parametric number of columns, rows, and 
--  testcases. For a given row (m) and column (n) count, this testbench creates a m x n Game of Life from the GOL entity. 
--  The testbench first feeds in a handful of edge cases to the Game of Life. After doing edge case checks, the testbench 
--  checks a set number of random test cases (default = 10). 
--
--  Each test process takes the following form:  
--  The testbench loops through the provided number of test cases and for each one, generates a random m x n initial state. 
--  The testbench then sends the Shift signal high and shifts this initial state into the game. 
--  The testbench then enters the game loop which we have set to a max 100 iterations (unless it converges early):
--
--  (1) Shift the current game status out & feed it back in the other end. As we shift data out we check if the shifted
--      out data matches what we expect given the iteration of the game. 
--
--  (2) Send the NextTimeTick signal high for 1 clock. This processes 1 iteration of the Game of Life algorithm in the
--      GOL entity. 
-- 
--  (3) Compute the next expected status of the game after 1 iteration has passed. Then return to (1) until 100 game iterations
--      have passed (unless game state converges early). 
--
--  After exiting the game loop, the testbench reports a completion message to the terminal then moves to the next test case
--  and repeats.  
--
--
--  The following details the types of test cases issued by the testbench::
--  For testing, as explained above, we begin by doing edge cases. To begin, we test the initial state of all 1's and then all
--  0's. After doing this generic edge case check, we use OSVVM coverage to construct more complex edge cases. To do this, we 
--  generate each row in the m x n game board seperately with the following OSVVM coverage: 
--       2 bins across range (0, 2**colcnt-1) -- 40 % of the time (random row)
--       1 bin on range (2**colcnt)           -- 20 % of the time (all 1's row)
--       1 bin on range (0)                   -- 20 % of the time (all 0's row)
--       1 bin on range(2**(colcnt/2))        -- 20 % of the time (half 1's, half 0's row)
--
--  After running these edge cases we generate a set amount of random cases to check (default = 10), following the same testing
--  process explained before. In these random test cases, each row on the m x n game board takes a random value. 
--
-- 
--
--  Note: for the default 10x10 game dimensions, the edge case coverage above takes about 15 iterations and lasts about 3 
--        minutes total in real time. Larger dimensions (i.e. 30x30) may take up to 2 hours unless the coverage above is 
--        adjusted. 
--
--  Revision History:
--     05 Mar 23  Hector Wilson       Initial revision.
--     06 Mar 23  Hector Wilson       Completed testbench. 
--     07 Mar 23  Hector Wilson       Added comments added edge case coverage. 
--
---------------------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
use osvvm.RandomPkg.all;
use osvvm.CoveragePkg.all;

entity GOL_tb is 
end GOL_tb; 

architecture Behavioral of GOL_tb is 
	-- Testbench interacts with top level Game of Life entity defined below. 
	component GOL 
		generic (
			rows : integer;
			columns : integer
		);
		port (
			clock : in std_logic;
			NextTimeTick : in std_logic;
			Shift : in std_logic;
			DataIn : in std_logic;
			DataOut : out std_logic
		);
	end component; 

	-- internal testbench signals
	signal finished : std_logic;         -- indicates if end of testbench is reached (terminates system clock)
	signal CLK : std_logic := '0';       -- system clock
	signal NextTimeTick : std_logic;     -- NextTimeTick signal fed into Game of Life entity
	signal Shift : std_logic; 		     -- Shift signal fed into Game of Life entity
	signal DataIn : std_logic;           -- DataIn signal fed into Game of Life entity
	signal DataOut : std_logic;          -- DataOut signal fed out of Game of Life entity 

	-- OSVVM coverage signal 
    signal CovGOL : CoverageIDType;      -- OSVVM coverage ID for Game of Life

	-- time period of system clock is 1 us
	constant period : time := 1 us; 

	-- parametrized row/column count and # of test cases
	constant colcnt : integer := 10;      -- # of rows in game board (m)
	constant rowcnt : integer := 10;      -- # of columns in game board (n)
	constant testcases : integer := 10;   -- # of different random test cases want to check in testbench for the m x n game

begin
CLK <= not CLK after period /2 when finished <= '0'; -- set up clock with frequency of 1 MHz (period = 1 us)
												     -- will terminate after reaching end of testbench 

-- Unit under test is the Game of Life top level entity containing the m x n systolic array												     
UUT : GOL
	generic map (
		rows => rowcnt,
		columns => colcnt
	)
    port map ( 
        clock => CLK,
        NextTimeTick => NextTimeTick,
        Shift => Shift,
        DataIn => DataIn,
        DataOut => DataOut
    );

-- Testbench process (follows the process defined in the header of this file)
process 
	variable testcase : integer;      -- random test case 
	variable testrow : integer;       -- random test row
	variable RV : RandomPType;        -- random variable
	variable edgecnt : integer := 0;  -- edge case test counter

	variable neighbors : integer; -- integer # of neighbors used for testbench game of life algorithm & calculating answer after each iteration

	variable state : std_logic_vector(rowcnt*colcnt-1 downto 0) := (others => '0');     -- contains the expected current state of the game
	variable state_new : std_logic_vector(rowcnt*colcnt-1 downto 0) := (others => '0'); -- contains the expected state of the game after 1 iteration
begin
	------------------------------------------------------------------------------------------------------------------------------------------------
	-- EDGE CASE CHECK
	------------------------------------------------------------------------------------------------------------------------------------------------
	-- begin by checking edge testcases --
	CovGOL <= NewID("CovGOL");
	wait for 0 ns; 

	-- OSVVM coverage explained in header
	AddBins(CovGOL, 4, GenBin(0, (2**colcnt)-1, 2));  -- 40% of the time, random row across 2 bins
	AddBins(CovGOL, 2, GenBin((2**colcnt)-1));     	  -- 20% of the time, all 1's row
	AddBins(CovGOL, 2, GenBin(0));                 	  -- 20% of the time, all 0's row
	AddBins(CovGOL, 2, GenBin((2**(colcnt/2))-1)); 	  -- 20% of the time, half 1's half 0's row  

	loop 
		-- for the first 2 edge case checks want to test all 1's and all 0's in the initial state
		-- for the rest of the edge case checks follow the OSVVM coverage
		if edgecnt > 1 then                -- beyond the second edge case check, we use OSVVM coverage to generate the initial state
			for i in 0 to rowcnt-1 loop
				(testrow) := GetRandPoint(CovGOL);
				state(colcnt*(i+1)-1 downto colcnt*i) := std_logic_vector(to_unsigned(testrow, colcnt));
			end loop;
		elsif edgecnt = 1 then             -- on the second edge case check, we check the all 1's initial state
			state := (others => '1');
		else                               -- on the first edge case check, we check the all 0's initial state 
			state := (others => '0');
		end if;

		-- shift initial state into systolic array
		Shift <= '1'; 
		NextTimeTick <= '0';
		for i in 0 to rowcnt*colcnt-1 loop
			DataIn <= state(i);
			wait for period; 
		end loop;
		Shift <= '0'; -- stop shifting now

		-- wait for 1 clock and then start checking this testcase & computing the Game of Life
		wait for period; 

		for i in 0 to 100 loop                                                         -- run each game for 100 iterations (unless converges early)  
			-----------------------------------------------------------    
			-- check if current game state matches what we expect
			--
			Shift <= '1';  
			NextTimeTick <= '0'; 
			for j in 0 to rowcnt*colcnt-1 loop                 
				DataIn <= DataOut;
				assert(DataOut = state(j))
					report "Incorrect at iteration " & integer'image(i)
					severity ERROR;

				wait for period; 
			end loop; 
			-----------------------------------------------------------
			Shift <= '0'; -- top shifting
			NextTimeTick <= '1'; -- start computing

			wait for period; 
			-----------------------------------------------------------
			-- Now, compute the next expected state of the game
			-- first, compute number of neighbors for each current cell
			for j in 0 to rowcnt-1 loop 
				for k in 0 to colcnt-1 loop
					if j = 0 and k = 0 then                         								-- top left corner
						neighbors := to_integer(unsigned'('0' & state(colcnt*j+k+1)))
				                   + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt)))
								   + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt+1))); 
					elsif j = 0 and k > 0 and k < colcnt-1 then                                     -- top edge
						neighbors := to_integer(unsigned'('0' & state(colcnt*j+k+1))) 
								   + to_integer(unsigned'('0' & state(colcnt*j+k-1)))
								   + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt)))
								   + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt+1)))
								   + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt-1)));
					elsif j = 0 and k = colcnt-1 then 												-- top right corner
						neighbors := to_integer(unsigned'('0' & state(colcnt*j+k-1)))
						           + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt)))
						           + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt-1))); 

				    elsif j > 0 and j < rowcnt-1 and k = 0 then                                     -- left edge
				    	neighbors := to_integer(unsigned'('0' & state(colcnt*j+k-colcnt)))
				    			   + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt+1)))
				    			   + to_integer(unsigned'('0' & state(colcnt*j+k+1)))
				    			   + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt)))
				    			   + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt+1)));
				    elsif j = rowcnt-1 and k = 0 then 											    -- bottom left corner
				    	neighbors := to_integer(unsigned'('0' & state(colcnt*j+k+1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt+1)));
				    elsif j = rowcnt-1 and k > 0 and k < colcnt-1 then 								-- bottom edge
				    	neighbors := to_integer(unsigned'('0' & state(colcnt*j+k+1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt-1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt+1)));
				    elsif j = rowcnt-1 and k = colcnt-1 then 										-- bottom right corner
				    	neighbors := to_integer(unsigned'('0' & state(colcnt*j+k-1)))
				    			   + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt)))
				    			   + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt-1)));
				    elsif j > 0 and j < rowcnt-1 and k = colcnt-1 then  						    -- right edge
				    	neighbors := to_integer(unsigned'('0' & state(colcnt*j+k-colcnt)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt-1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt))) 
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt-1))); 
				    else                                                                            -- interior cell
				    	neighbors := to_integer(unsigned'('0' & state(colcnt*j+k-1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k+1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt-1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt+1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt-1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt+1))); 
					end if; 

					-- determine the new state the cell using the generated neighbors above
					if state(colcnt*j+k) = '1' then 											    -- if cell alive
						if neighbors = 2 or neighbors = 3 then 
							state_new(colcnt*j+k) := '1'; 
						else 
							state_new(colcnt*j+k) := '0';
						end if;
					else 				
						if neighbors = 3 then 													    -- if cell dead
							state_new(colcnt*j+k) := '1';
						else 
							state_new(colcnt*j+k) := '0';
						end if; 
					end if;

				end loop;
			end loop;

			-- update expected state of game with the new state calculated above
			next when state = state_new; -- if game has converged earlier than 100 iterations then move to next test
			state := state_new; 		 -- otherwise, update game state with next state and loop to beginning
		end loop;

		-- Check if we have covered all cases, if not loop back and repeat with different test case
		ICover(CovGOL, testrow);
		exit when IsCovered(CovGOL);

		edgecnt := edgecnt + 1; 
		report "Finished Edge Case Test " & integer'image(edgecnt);

	end loop;

	report "Starting Random Test Cases";
	------------------------------------------------------------------------------------------------------------------------------------------------
	-- RANDOM CASE CHECK
	------------------------------------------------------------------------------------------------------------------------------------------------
	-- check an additional number of random testcases --
	for c in 0 to testcases-1 loop

		-- randomly generate initial game board state
		for i in 0 to rowcnt*colcnt-1 loop
			testcase := RV.RandInt(0,1);
			state(i) := '0' when testcase = 0 else
						'1'; 
		end loop;

		-- shift initial state into systolic array
		Shift <= '1'; 
		NextTimeTick <= '0';
		for i in 0 to rowcnt*colcnt-1 loop
			DataIn <= state(i);
			wait for period; 
		end loop;
		Shift <= '0'; -- stop shifting now

		-- wait for 1 clock and then start checking this testcase & computing the Game of Life
		wait for period; 

		for i in 0 to 100 loop                                                         -- run each game for 100 iterations (unless converges early)  
			-----------------------------------------------------------    
			-- check if current game state matches what we expect
			--
			Shift <= '1';  
			NextTimeTick <= '0'; 
			for j in 0 to rowcnt*colcnt-1 loop                 
				DataIn <= DataOut;
				assert(DataOut = state(j))
					report "Incorrect at iteration " & integer'image(i)
					severity ERROR;

				wait for period; 
			end loop; 
			-----------------------------------------------------------
			Shift <= '0'; -- top shifting
			NextTimeTick <= '1'; -- start computing

			wait for period; 
			-----------------------------------------------------------
			-- Now, compute the next expected state of the game
			-- first, compute number of neighbors for each current cell
			for j in 0 to rowcnt-1 loop 
				for k in 0 to colcnt-1 loop
					if j = 0 and k = 0 then                         								-- top left corner
						neighbors := to_integer(unsigned'('0' & state(colcnt*j+k+1)))
				                   + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt)))
								   + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt+1))); 
					elsif j = 0 and k > 0 and k < colcnt-1 then                                     -- top edge
						neighbors := to_integer(unsigned'('0' & state(colcnt*j+k+1))) 
								   + to_integer(unsigned'('0' & state(colcnt*j+k-1)))
								   + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt)))
								   + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt+1)))
								   + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt-1)));
					elsif j = 0 and k = colcnt-1 then 												-- top right corner
						neighbors := to_integer(unsigned'('0' & state(colcnt*j+k-1)))
						           + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt)))
						           + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt-1))); 

				    elsif j > 0 and j < rowcnt-1 and k = 0 then                                     -- left edge
				    	neighbors := to_integer(unsigned'('0' & state(colcnt*j+k-colcnt)))
				    			   + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt+1)))
				    			   + to_integer(unsigned'('0' & state(colcnt*j+k+1)))
				    			   + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt)))
				    			   + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt+1)));
				    elsif j = rowcnt-1 and k = 0 then 											    -- bottom left corner
				    	neighbors := to_integer(unsigned'('0' & state(colcnt*j+k+1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt+1)));
				    elsif j = rowcnt-1 and k > 0 and k < colcnt-1 then 								-- bottom edge
				    	neighbors := to_integer(unsigned'('0' & state(colcnt*j+k+1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt-1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt+1)));
				    elsif j = rowcnt-1 and k = colcnt-1 then 										-- bottom right corner
				    	neighbors := to_integer(unsigned'('0' & state(colcnt*j+k-1)))
				    			   + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt)))
				    			   + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt-1)));
				    elsif j > 0 and j < rowcnt-1 and k = colcnt-1 then  						    -- right edge
				    	neighbors := to_integer(unsigned'('0' & state(colcnt*j+k-colcnt)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt-1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt))) 
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt-1))); 
				    else                                                                            -- interior cell
				    	neighbors := to_integer(unsigned'('0' & state(colcnt*j+k-1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k+1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt-1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k-colcnt+1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt-1)))
				    	           + to_integer(unsigned'('0' & state(colcnt*j+k+colcnt+1))); 
					end if; 

					-- determine the new state the cell using the generated neighbors above
					if state(colcnt*j+k) = '1' then 											    -- if cell alive
						if neighbors = 2 or neighbors = 3 then 
							state_new(colcnt*j+k) := '1'; 
						else 
							state_new(colcnt*j+k) := '0';
						end if;
					else 				
						if neighbors = 3 then 													    -- if cell dead
							state_new(colcnt*j+k) := '1';
						else 
							state_new(colcnt*j+k) := '0';
						end if; 
					end if;

				end loop;
			end loop;

			-- update expected state of game with the new state calculated above
			next when state = state_new; -- if game has converged earlier than 100 iterations then move to next test
			state := state_new; 		 -- otherwise, update game state with next state and loop to beginning
		end loop;
		--------------------------------------------------------------------------

		-- loop back and repeat with different test case
		report "Finished Random Test Case " & integer'image(c+1);
	end loop;


	finished <= '1'; -- end of testbench (terminate system clock)
	wait; 

end process; 

end Behavioral; 