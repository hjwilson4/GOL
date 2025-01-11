///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  
//  Conway's Game of Life
//
//  This file contains the individual cells for Conway's Game of Life. Each cell receives 8 inputs from the 8 cardinal
//  directions surrounding the cell in the systolic array. Additionally, each cell contains a clock input, a Shift signal 
//  input, a NextTimeTick input, and a DataIn input. Each cell has only one output, which is its current status (0 = dead 
//  or 1 = alive). 
//
//  On the rising edge of the clock, the cell updates as follows:
//   - If NextTimeTick is active, the cell updates according to the rules of Conway's Game of Life. 
//     - If the cell is dead and exactly 3 neighbors are alive, the cell becomes alive.
//     - If the cell is alive and has 2 or 3 neighbors alive, the cell remains alive.
//     - In all other cases, the cell dies (either due to overpopulation or underpopulation).
//   - If Shift is active, the cell shifts the DataIn input into its current status. This is used to shift in the initial 
//     states of the game or to check results after each iteration. 
//
//  Revision History:
//     05 Mar 23  Hector Wilson       Initial revision.
//     06 Mar 23  Hector Wilson       Completed assignment. Updated calculation of neighbors. 
//     07 Mar 23  Hector Wilson       Updated calculation of neighbors to optimize for space and added comments.
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

module GOLCell (
    input logic clock,              // Global clock
    input logic NextTimeTick,       // Game tick signal
    input logic Shift,              // Shift data signal
    input logic DataIn,             // Input data for shifting

    input logic top_left,           // Top-left neighbor
    input logic top_right,          // Top-right neighbor
    input logic bot_left,           // Bottom-left neighbor
    input logic bot_right,          // Bottom-right neighbor
    input logic mid_left,           // Middle-left neighbor
    input logic mid_right,          // Middle-right neighbor
    input logic mid_top,            // Middle-top neighbor
    input logic mid_bot,            // Middle-bottom neighbor

    output logic status             // Current cell status (0 = dead, 1 = alive)
);


    // Internal register to store the current status
    logic status0;

    // Define neighbors as a 3-bit wide signal to store the sum of up to 8 neighbors.
    logic [2:0] neighbors;

    // Calculate the number of alive neighbors (explicitly widen the inputs to 3 bits).
    always_comb begin
        neighbors = ({2'b0, top_left} + {2'b0, top_right} + 
                     {2'b0, bot_left} + {2'b0, bot_right} + 
                     {2'b0, mid_left} + {2'b0, mid_right} + 
                     {2'b0, mid_top} + {2'b0, mid_bot});
    end

    // Update the status based on the game rules
    always_ff @(posedge clock) begin
        if (NextTimeTick) begin
            if (status0 == 0) begin
                // Cell is dead, check if exactly 3 neighbors are alive
                if (neighbors == 3) 
                    status0 <= 1;  // Cell becomes alive
                else 
                    status0 <= 0;  // Cell remains dead
            end else begin
                // Cell is alive, check if 2 or 3 neighbors are alive
                if (neighbors == 2 || neighbors == 3)
                    status0 <= 1;  // Cell remains alive
                else 
                    status0 <= 0;  // Cell dies
            end
        end

        // If Shift is active, the cell takes the value of DataIn as its new status
        if (Shift) begin
            status0 <= DataIn;  // Shift in new status from DataIn
        end
    end

    // Output the current status
    assign status = status0;

endmodule
