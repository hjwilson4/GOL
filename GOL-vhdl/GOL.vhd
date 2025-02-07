---------------------------------------------------------------------------------------------------------------------------
--
--  Conway's Game of Life
--
--  This file contains the top level implementation of Conway's Game of Life using a parametrized m x n systolic array. 
--  The top level entity hooks up a total of m x n Game of life cells in an m x n array. The top level contains 4 inputs 
--  and 2 outputs. The clock input is the system clock. The NextTimeTick and Shift inputs are mode selection signals which 
--  determine how the cells update on the rising edge of clock (internal to each cell). The DataIn input is used to shift
--  data into the systolic array. The DataOut output is the shifted out data when shifting data into the systolic array. 
--  The systolic array is set up so that data is shifted into (from DataIn) the upper left corner of the m x n array and 
--  out (into DataOut) from the bottom right corner of the m x n array. 
--
--  On the rising edge of clock, each of the m x n cells updates as follows:
--  	if NextTimeTick active then each cell updates according the rules of Conway's Game of Life. To do this, each cell
--      computes the number of 'alive' neighbors surrounding itself. If the cell is currently dead and exactly 3 neighbors
--      are alive, then the cell is resurrected and becomes alive. Otherwise, the dead cell remains dead. If the cell is 
--      currently alive and either 2 or 3 neighbors are alive, then the cell remains alive. Otherwise, the alive cell dies
--      due to overpopulation. 
--
--      Note: in this version of the Game of Life, boundaries are closed and set to dead. 
--
--		if Shift active then data is shifted into (from DataIn) the systolic array starting at the upper left corner and out 
--      (to DataOut) from the bottom right corner. Aside from these two corner cases, data shifts to the cell to immediate 
--      right of each cell. If a cell is at the right edge of m x n array then it shifts its data into the far left edge of 
--      the next row below. This shift mode is used for loading in initial states into the game as well as for checking the 
--      status of the game after each iteration. 
--
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

entity GOL is 
	generic (
		rows  :  integer := 10;    -- default # of rows is 10 
		columns : integer := 10    -- default # of columns is 10 
	);

	port (
		clock : in std_logic;           -- system clock 
		NextTimeTick : in std_logic;    -- indicates if game is played
		Shift : in std_logic;           -- indicates if data is being shifted in/out
		DataIn : in std_logic;          -- contains data to be shifted in 
		DataOut : out std_logic         -- contains data that is being shifted out
	);

end GOL;

architecture Behavioral of GOL is 
	-- The systolic array contains m x n Game of Life Cell components defined below. 
	component GOLCell 
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
	end component;

	-- There is one top level status signal that is used for propogating shifted data through the systolic array
	signal status : std_logic_vector(rows*columns-1 downto 0);

begin

--------------------------------------------------------------------------------------------------------------------
-- Now, generate the m x n array. 
ArrayRows:
   for i in 0 to rows-1 generate
	begin
	ArrayColumns: 
		for j in 0 to columns-1 generate
		begin
		ArrayLeftEdge:
			if j = 0 and i < rows-1 and i > 0 generate          				  -- left edge no corner
				LeftEdgeCell : GOLCell 
					port map (
						status => status(columns*i+j),
						Shift => Shift,
						NextTimeTick => NextTimeTick,
						clock => clock,
						DataIn => status(columns*i+j-1), 

						top_left => '0',
						top_right => status(columns*i+j-columns+1),
						bot_left => '0',
						bot_right => status(columns*i+j+columns+1),
						mid_left => '0',
						mid_right => status(columns*i+j+1),
						mid_top => status(columns*i+j-columns),
						mid_bot => status(columns*i+j+columns)
					);
			end generate ArrayLeftEdge;
		ArrayTopLeft:
			if j = 0 and i = 0 generate                      					 -- top left corner
				TopLeftCell : GOLCell 
					port map (
						status => status(columns*i+j),
						Shift => Shift,
						NextTimeTick => NextTimeTick,
						clock => clock,
						DataIn => DataIn, 										 -- shift DataIn into top left

						top_left => '0',
						top_right => '0',
						bot_left => '0',
						bot_right => status(columns*i+j+columns+1),
						mid_left => '0',
						mid_right => status(columns*i+j+1),
						mid_top => '0',
						mid_bot => status(columns*i+j+columns)
					);
			end generate ArrayTopLeft;
		ArrayBotLeft:
			if j = 0 and i = rows-1 generate                                     -- bottom left corner							
				BotLeftCell : GOLCell 
					port map (
						status => status(columns*i+j),
						Shift => Shift,
						NextTimeTick => NextTimeTick,
						clock => clock,
						DataIn => status(columns*i+j-1), 

						top_left => '0',
						top_right => status(columns*i+j-columns+1),
						bot_left => '0',
						bot_right => '0', 
						mid_left => '0',
						mid_right => status(columns*i+j+1),
						mid_top => status(columns*i+j-columns),
						mid_bot => '0'
					);
			end generate ArrayBotLeft;
		ArrayRightEdge:
			if j = columns-1 and i < rows-1 and i > 0 generate                  -- right edge no corner
				RightEdgeCell : GOLCell 
					port map (
						status => status(columns*i+j),
						Shift => Shift,
						NextTimeTick => NextTimeTick,
						clock => clock,
						DataIn => status(columns*i+j-1), 

						top_left => status(columns*i+j-columns-1),
						top_right => '0',
						bot_left => status(columns*i+j+columns-1),
						bot_right => '0',
						mid_left => status(columns*i+j-1),
						mid_right => '0',
						mid_top => status(columns*i+j-columns),
						mid_bot => status(columns*i+j+columns)
					);
			end generate ArrayRightEdge;
		ArrayTopRight:
			if j = columns-1 and i = 0 generate								    -- top right corner
				TopRightCell : GOLCell 
					port map (
						status => status(columns*i+j),
						Shift => Shift,
						NextTimeTick => NextTimeTick,
						clock => clock,
						DataIn => status(columns*i+j-1), 

						top_left => '0',
						top_right => '0',
						bot_left => status(columns*i+j+columns-1),
						bot_right => '0',
						mid_left => status(columns*i+j-1),
						mid_right => '0',
						mid_top => '0',
						mid_bot => status(columns*i+j+columns)
					);
			end generate ArrayTopRight;
		ArrayBotRight:
			if j = columns-1 and i = rows-1 generate                             -- bottom right corner
				BotRightCell : GOLCell 
					port map (
						status => status(columns*i+j),
						Shift => Shift,
						NextTimeTick => NextTimeTick,
						clock => clock,
						DataIn => status(columns*i+j-1), 

						top_left => status(columns*i+j-columns-1),
						top_right => '0',
						bot_left => '0',
						bot_right => '0',
						mid_left => status(columns*i+j-1),
						mid_right => '0',
						mid_top => status(columns*i+j-columns),
						mid_bot => '0'
					);
			end generate ArrayBotRight;
		ArrayTopEdge:
			if j < columns-1 and j > 0 and i = 0 generate                        -- top edge no corner
				TopEdgeCell : GOLCell 
					port map (
						status => status(columns*i+j),
						Shift => Shift,
						NextTimeTick => NextTimeTick,
						clock => clock,
						DataIn => status(columns*i+j-1), 

						top_left => '0',
						top_right => '0',
						bot_left => status(columns*i+j+columns-1),
						bot_right => status(columns*i+j+columns+1), 
						mid_left => status(columns*i+j-1),
						mid_right => status(columns*i+j+1),
						mid_top => '0',
						mid_bot => status(columns*i+j+columns)
					);
			end generate ArrayTopEdge;
		ArrayBotEdge:
			if j < columns-1 and j > 0 and i = rows-1 generate                   -- bottom edge no corner
				BotEdgeCell : GOLCell 
					port map (
						status => status(columns*i+j),
						Shift => Shift,
						NextTimeTick => NextTimeTick,
						clock => clock,
						DataIn => status(columns*i+j-1), 

						top_left => status(columns*i+j-columns-1),
						top_right => status(columns*i+j-columns+1),
						bot_left => '0',
						bot_right => '0',
						mid_left => status(columns*i+j-1),
						mid_right => status(columns*i+j+1),
						mid_top => status(columns*i+j-columns),
						mid_bot => '0'
					);
			end generate ArrayBotEdge;
		ArrayInt:
			if j < columns-1 and j > 0 and i < rows-1 and i > 0 generate         -- interior cell
				IntCell : GOLCell 
					port map (
						status => status(columns*i+j),
						Shift => Shift,
						NextTimeTick => NextTimeTick,
						clock => clock,
						DataIn => status(columns*i+j-1), 

						top_left => status(columns*i+j-columns-1),
						top_right => status(columns*i+j-columns+1),
						bot_left => status(columns*i+j+columns-1),
						bot_right => status(columns*i+j+columns+1), 
						mid_left => status(columns*i+j-1),
						mid_right => status(columns*i+j+1),
						mid_top => status(columns*i+j-columns),
						mid_bot => status(columns*i+j+columns)
					);
			end generate ArrayInt;
		end generate ArrayColumns;
	end generate ArrayRows;

-- DataOut simply comes the last cell in the systolic array. 
DataOut <= status(columns*rows-1);


end Behavioral;