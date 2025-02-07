---------------------------------------------------------------------------------------------------------------------------
--
--  Conway's Game of Life
--
--  This file contains the individual cells for Conway's Game of Life. Each cell contains 8 inputs from the 8 cardinal
--  cardinal directions surrounding the cell in the systolic array. Additionally, each cell contains a clock input, a Shift
--  signal input, a NextTimeTick input, and a DataIn input. Each cell has only output which is its current status (0-dead 
--  or 1-alive). 
--
--  On the rising edge of clock, the cell updates as follows:
--  	if NextTimeTick active then the cell updates according the rules of Conway's Game of Life. To do this, this entity 
--      computes the number of 'alive' neighbors surrounding the cell. If the cell is currently dead and exactly 3 neighbors
--      are alive, then the cell is resurrected and becomes alive. Otherwise, the dead cell remains dead. If the cell is 
--      currently alive and either 2 or 3 neighbors are alive, then the cell remains alive. Otherwise, the alive cell dies
--      due to overpopulation. 
--
--		if Shift active then the cell shifts the DataIn input into its current status. This mode is used to shift in initial 
--      states into the game and for the purposes of checking results after each game iteration. 
--
--
--  Revision History:
--     05 Mar 23  Hector Wilson       Initial revision.
--     06 Mar 23  Hector Wilson 	  Completed assignment. Updated calculation of neighbors. 
--     07 Mar 23  Hector Wilson       Updated calculation of neighbors to optimize for space. 
--                                    Added comments. 
--
---------------------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Each Game of Life Cell contains a total of 12 inputs and 1 input. The clock input is the global clock for the system. 
-- The NextTimeTick input indicates when the game is being played. The Shift input indicates data is being shifted through
-- the systolic array and shifts in the DataIn input. The next 8 inputs are the status from the surrounding cells in the 
-- systolic array. These 8 inputs are used to calculate the # of neighbors for the game algorithm. Lastly, the Cell has 
-- only one output which is its current status (0--dead or 1--alive). 

entity GOLCell is 
	port (
		clock : in std_logic; 
		NextTimeTick : in std_logic;
		Shift : in std_logic;
		DataIn : in std_logic;

		top_left : in std_logic;
		top_right : in std_logic;
		bot_left : in std_logic;
		bot_right : in std_logic;
		mid_left : in std_logic;
		mid_right : in std_logic;
		mid_top : in std_logic;
		mid_bot : in std_logic;

		status : out std_logic
	);
end GOLCell;


architecture Behavioral of GOLCell is 
	signal neighbors : unsigned(2 downto 0); -- neighbors signal indicates # of alive neighbors to this cell

	signal status0 : std_logic; 			 -- the same output status signal fed back into circuit for use in 
											 -- game algorithm.   
begin
	-------------------------------------------------------------------------------------------------------------------
	-- first this counts the number of neighbors that are alive and sends the result to the signal neighbors.
	-- since the max value of neighbors is 8, we cap the neighbors signal to 3 bits since we only care about values
	-- of neighbors = 2 or neighbors = 3. 
	neighbors <= ("00" & top_left) + ("00" & top_right) + ("00" & bot_left) + ("00" & bot_right) + ("00" & mid_left)
			   + ("00" & mid_right) + ("00" & mid_top) + ("00" & mid_bot);

	-------------------------------------------------------------------------------------------------------------------
	-- this process implements the DFFs that update the status of the cell depending on the mode we are operating in 
	-- NextTimeTick = '1' --> update according to Game Algorithm:
	--                        If Cell = Dead:
	--                            If neighbors = 3 then 
	--                               Cell <= Alive
	--                            else
	--                               Cell <= Dead
	--                        else (Cell = Alive) 
	--                            If neighbors = 2 or neighbors = 3 then 
	--                            	 Cell <= Alive
	--                            else
	--                               Cell <= Dead
	-- Shift = '1' --> shift status in from DataIn input. 
	-- 

	process(clock) begin
		if rising_edge(clock) then 
			if NextTimeTick = '1' then 
				if status0 = '0' then  					                        -- if cell is currently dead
					if neighbors = "011" then  				                    -- cell is reborn if exactly 3 neighbors
						status0 <= '1';    									    -- otherwise remains dead
					end if;
				else                  					                        -- if cell is currently alive
					if neighbors = "010" or neighbors = "011" then              -- cell survives if exactly 2 or 3 neighbors
						status0 <= '1';                                      
					else 								                        -- otherwise, cell dies
						status0 <= '0';
					end if;
				end if;
			end if;

			if Shift = '1' then  
				status0 <= DataIn; 												-- if shift active then shift status in
			end if; 														    -- from DataIn
		end if; 
	end process;

	status <= status0;

end Behavioral;