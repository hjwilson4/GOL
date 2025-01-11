///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  
//  Conway's Game of Life
//
//  This file contains the top-level implementation of Conway's Game of Life using a parametrized m x n systolic array. 
//  The top-level entity connects a total of m x n Game of Life cells in an m x n array. The top level contains 4 inputs 
//  and 2 outputs. The clock input is the system clock. The NextTimeTick and Shift inputs are mode selection signals which 
//  determine how the cells update on the rising edge of the clock (internal to each cell). The DataIn input is used to shift
//  data into the systolic array. The DataOut output is the shifted out data when shifting data into the systolic array. 
//  The systolic array is set up so that data is shifted into (from DataIn) the upper left corner of the m x n array and 
//  out (into DataOut) from the bottom right corner of the m x n array. 
//
//  On the rising edge of the clock, each of the m x n cells updates as follows:
//   - If NextTimeTick is active, each cell updates according to the rules of Conway's Game of Life. 
//     - If the cell is currently dead and exactly 3 neighbors are alive, the cell is resurrected and becomes alive.
//     - If the cell is currently alive and either 2 or 3 neighbors are alive, the cell remains alive.
//     - In all other cases, the cell dies due to overpopulation or underpopulation.
//  
//  Note: In this version of the Game of Life, boundaries are closed and set to dead. 
//
//  If Shift is active, data is shifted into (from DataIn) the systolic array starting at the upper left corner and out 
//  (to DataOut) from the bottom right corner. Aside from these two corner cases, data shifts to the immediate right of 
//  each cell. If a cell is at the right edge of the m x n array, it shifts its data into the far left edge of the next 
//  row below. This shift mode is used for loading in initial states into the game as well as for checking the status of 
//  the game after each iteration. 
//
//  Revision History:
//     05 Mar 23  Hector Wilson       Initial revision.
//     06 Mar 23  Hector Wilson       Completed assignment. Updated calculation of neighbors. 
//     07 Mar 23  Hector Wilson       Updated calculation of neighbors to optimize for space and added comments.
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

module GOL #(
    parameter integer rows = 10,     // Default number of rows
    parameter integer columns = 10   // Default number of columns
)(
    input logic clock,               // System clock
    input logic NextTimeTick,        // Game play signal
    input logic Shift,               // Data shift signal
    input logic DataIn,              // Input data to shift in
    output logic DataOut             // Output data shifted out
);

    // Declare the array of Game of Life cells
    logic [rows*columns-1:0] status; 

    // Instantiate each Game of Life cell in the systolic array
    genvar i, j;
    generate
        for (i = 0; i < rows; i = i + 1) begin : ArrayRows
            for (j = 0; j < columns; j = j + 1) begin : ArrayColumns
                // Left edge cell (non-corner)
                if (j == 0 && i > 0 && i < rows-1) begin : ArrayLeftEdge
                    GOLCell LeftEdgeCell (
                        .status(status[columns*i+j]),
                        .Shift(Shift),
                        .NextTimeTick(NextTimeTick),
                        .clock(clock),
                        .DataIn(status[columns*i+j-1]),

                        .top_left(0),
                        .top_right(status[columns*(i-1)+j+1]),
                        .bot_left(0),
                        .bot_right(status[columns*(i+1)+j+1]),
                        .mid_left(0),
                        .mid_right(status[columns*i+j+1]),
                        .mid_top(status[columns*(i-1)+j]),
                        .mid_bot(status[columns*(i+1)+j])
                    );
                end
                // Top-left corner cell
                else if (i == 0 && j == 0) begin : ArrayTopLeft
                    GOLCell TopLeftCell (
                        .status(status[columns*i+j]),
                        .Shift(Shift),
                        .NextTimeTick(NextTimeTick),
                        .clock(clock),
                        .DataIn(DataIn),  // Shift in data into the top-left corner

                        .top_left(0),
                        .top_right(0),
                        .bot_left(0),
                        .bot_right(status[columns*i+j+columns+1]),
                        .mid_left(0),
                        .mid_right(status[columns*i+j+1]),
                        .mid_top(0),
                        .mid_bot(status[columns*i+j+columns])
                    );
                end
                // Bottom-left corner cell
                else if (i == rows-1 && j == 0) begin : ArrayBotLeft
                    GOLCell BotLeftCell (
                        .status(status[columns*i+j]),
                        .Shift(Shift),
                        .NextTimeTick(NextTimeTick),
                        .clock(clock),
                        .DataIn(status[columns*i+j-1]),

                        .top_left(0),
                        .top_right(status[columns*(i-1)+j+1]),
                        .bot_left(0),
                        .bot_right(0),
                        .mid_left(0),
                        .mid_right(status[columns*i+j+1]),
                        .mid_top(status[columns*(i-1)+j]),
                        .mid_bot(0)
                    );
                end
                // Right edge cell (non-corner)
                else if (j == columns-1 && i > 0 && i < rows-1) begin : ArrayRightEdge
                    GOLCell RightEdgeCell (
                        .status(status[columns*i+j]),
                        .Shift(Shift),
                        .NextTimeTick(NextTimeTick),
                        .clock(clock),
                        .DataIn(status[columns*i+j-1]),

                        .top_left(status[columns*(i-1)+j-1]),
                        .top_right(0),
                        .bot_left(status[columns*(i+1)+j-1]),
                        .bot_right(0),
                        .mid_left(status[columns*i+j-1]),
                        .mid_right(0),
                        .mid_top(status[columns*(i-1)+j]),
                        .mid_bot(status[columns*(i+1)+j])
                    );
                end
                // Top-right corner cell
                else if (i == 0 && j == columns-1) begin : ArrayTopRight
                    GOLCell TopRightCell (
                        .status(status[columns*i+j]),
                        .Shift(Shift),
                        .NextTimeTick(NextTimeTick),
                        .clock(clock),
                        .DataIn(status[columns*i+j-1]),

                        .top_left(0),
                        .top_right(0),
                        .bot_left(status[columns*(i+1)+j-1]),
                        .bot_right(0),
                        .mid_left(status[columns*i+j-1]),
                        .mid_right(0),
                        .mid_top(0),
                        .mid_bot(status[columns*(i+1)+j])
                    );
                end
                // Bottom-right corner cell
                else if (i == rows-1 && j == columns-1) begin : ArrayBotRight
                    GOLCell BotRightCell (
                        .status(status[columns*i+j]),
                        .Shift(Shift),
                        .NextTimeTick(NextTimeTick),
                        .clock(clock),
                        .DataIn(status[columns*i+j-1]),

                        .top_left(status[columns*(i-1)+j-1]),
                        .top_right(0),
                        .bot_left(0),
                        .bot_right(0),
                        .mid_left(status[columns*i+j-1]),
                        .mid_right(0),
                        .mid_top(status[columns*(i-1)+j]),
                        .mid_bot(0)
                    );
                end
                // Top edge cell (non-corner)
                else if (i == 0 && j > 0 && j < columns-1) begin : ArrayTopEdge
                    GOLCell TopEdgeCell (
                        .status(status[columns*i+j]),
                        .Shift(Shift),
                        .NextTimeTick(NextTimeTick),
                        .clock(clock),
                        .DataIn(status[columns*i+j-1]),

                        .top_left(0),
                        .top_right(0),
                        .bot_left(status[columns*(i+1)+j-1]),
                        .bot_right(status[columns*(i+1)+j+1]),
                        .mid_left(status[columns*i+j-1]),
                        .mid_right(status[columns*i+j+1]),
                        .mid_top(0),
                        .mid_bot(status[columns*(i+1)+j])
                    );
                end
                // Bottom edge cell (non-corner)
                else if (i == rows-1 && j > 0 && j < columns-1) begin : ArrayBotEdge
                    GOLCell BotEdgeCell (
                        .status(status[columns*i+j]),
                        .Shift(Shift),
                        .NextTimeTick(NextTimeTick),
                        .clock(clock),
                        .DataIn(status[columns*i+j-1]),

                        .top_left(status[columns*(i-1)+j-1]),
                        .top_right(status[columns*(i-1)+j+1]),
                        .bot_left(0),
                        .bot_right(0),
                        .mid_left(status[columns*i+j-1]),
                        .mid_right(status[columns*i+j+1]),
                        .mid_top(status[columns*(i-1)+j]),
                        .mid_bot(0)
                    );
                end
                // Interior cell
                else if (i > 0 && i < rows-1 && j > 0 && j < columns-1) begin : ArrayInt
                    GOLCell IntCell (
                        .status(status[columns*i+j]),
                        .Shift(Shift),
                        .NextTimeTick(NextTimeTick),
                        .clock(clock),
                        .DataIn(status[columns*i+j-1]),

                        .top_left(status[columns*(i-1)+j-1]),
                        .top_right(status[columns*(i-1)+j+1]),
                        .bot_left(status[columns*(i+1)+j-1]),
                        .bot_right(status[columns*(i+1)+j+1]),
                        .mid_left(status[columns*i+j-1]),
                        .mid_right(status[columns*i+j+1]),
                        .mid_top(status[columns*(i-1)+j]),
                        .mid_bot(status[columns*(i+1)+j])
                    );
                end
            end
        end
    endgenerate

    // DataOut is the last cell in the systolic array (bottom-right corner)
    assign DataOut = status[columns*rows-1];

endmodule

