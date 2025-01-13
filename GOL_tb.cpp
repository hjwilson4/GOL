#include "VGOL.h"
#include <verilated.h>
#include <stdlib.h>
#include <iostream>
#include <vector>
#include <random>
#include "GOL_GUI.h"
#if VM_TRACE
#include "verilated_vcd_c.h"
#endif


using namespace std;
vluint64_t sim_time = 0; // sim time 


// Function to update SystemVerilog RTL
// 1. evaluates all RTL logic
// 2. dump trace for vcd waveform
// 3. increment simulation time
void updateRTL(VGOL* dut, vluint64_t &sim_time, VerilatedVcdC* tfp) {
    dut->eval();
    tfp->dump(sim_time);
    sim_time++;
}

// Function to generate random n*m game state
// n rows 
// m cols
vector<vector<bool>> generate_stimulus(int n, int m) {
    random_device rd;
    mt19937 gen(rd());
    uniform_int_distribution<> dis(0, 1);
    vector<vector<bool>> stimulus(n, vector<bool>(m));

    for (int i = 0; i < n; ++i) {
        for (int j = 0; j < m; ++j) {
            stimulus[i][j] = dis(gen);
        }
    }

    return stimulus;
}

// Function to initialize a p46 gun in the Game of Life
vector<vector<bool>> p46_gun(int n, int m) {
    vector<vector<bool>> gun(n, vector<bool>(m, false));

    auto set_cell = [&](int row, int col) {
        if (row >= 0 && row < n && col >= 0 && col < m) {
            gun[row][col] = true;
        }
    };

    // Gun pattern (This is the p46 gun configuration)
    // Gun size: 46x13
    set_cell(2, 1); set_cell(2, 2); set_cell(3, 1); set_cell(3, 2);
    set_cell(9, 1); set_cell(9, 2); set_cell(10, 1); set_cell(10, 2);

    set_cell(2, 15); set_cell(2, 16); set_cell(2, 19);
    set_cell(3, 15); set_cell(3, 17); set_cell(3, 18);
    set_cell(4, 16);
    set_cell(5, 16); set_cell(5, 17); set_cell(5, 18);

    set_cell(7, 16); set_cell(7, 17); set_cell(7, 18);
    set_cell(8, 16);
    set_cell(9, 15); set_cell(9, 17); set_cell(9, 18);
    set_cell(10, 15); set_cell(10, 16); set_cell(10, 19);

    set_cell(2, 24); set_cell(2, 25);
    set_cell(3, 25); set_cell(3, 26);
    set_cell(4, 23); set_cell(4, 25);
    set_cell(5, 23); set_cell(5, 24);

    set_cell(7, 23); set_cell(7, 24);
    set_cell(8, 23); set_cell(8, 25);
    set_cell(9, 25); set_cell(9, 26);
    set_cell(10, 24); set_cell(10, 25);

    set_cell(2, 28); set_cell(2, 29);
    set_cell(3, 28); set_cell(3, 29);

    set_cell(17, 32); set_cell(17, 33); set_cell(17, 34);
    set_cell(18, 31); set_cell(18, 35);
    set_cell(19, 30); set_cell(19, 34); set_cell(19, 35);
    set_cell(20, 30); set_cell(20, 32); set_cell(20, 33);
    set_cell(21, 32);

    set_cell(17, 38); set_cell(17, 39); set_cell(17, 40);
    set_cell(18, 37); set_cell(18, 41);
    set_cell(19, 37); set_cell(19, 38); set_cell(19, 42);
    set_cell(20, 39); set_cell(20, 40); set_cell(20, 42);
    set_cell(21, 40);

    set_cell(32, 32); set_cell(32, 33);
    set_cell(33, 32); set_cell(33, 33);

    set_cell(32, 39); set_cell(32, 40);
    set_cell(33, 39); set_cell(33, 40);

    return gun;
}

// Function to apply stimulus game state to the GOL DUT  
void apply_stimulus(VGOL* dut, vector<vector<bool>>& stimulus, vluint64_t &sim_time, VerilatedVcdC* tfp) {
    // Send shift high to indicate we are loading in game state
    dut->Shift = 1;
    for (int i = stimulus.size()-1; i >= 0; --i) {
        for (int j = stimulus[0].size()-1; j >= 0; --j) {
            dut->DataIn = stimulus[i][j];
            dut->clock = 1;
            updateRTL(dut, sim_time, tfp);
            dut->clock = 0;
            updateRTL(dut, sim_time, tfp);
        }
    }
    // Reset shift logic and hold for 1 clock
    dut->Shift = 0;
    dut->clock = 1;
    updateRTL(dut, sim_time, tfp);
    dut->clock = 0;
    updateRTL(dut, sim_time, tfp);
}

// Function to print grid (for debug purposes)
void print_grid(const char* label, vector<vector<bool>>& stimulus) {
    cout << label << "\n";
    for (int i = 0; i < stimulus.size(); ++i) {
        for (int j = 0; j < stimulus[0].size(); ++j) {
            cout << stimulus[i][j] << " ";
        }
        cout << "\n";
    }
}

// Function to capture DUT output game state
// DUT game state will be stored in the variable game_state
void capture_game_state(VGOL* dut, vector<vector<bool>>& game_state, vluint64_t &sim_time, VerilatedVcdC* tfp) {
    // Send shift signal high to shift out gamestate
    dut->Shift = 1;
    for (int i = game_state.size()-1; i >= 0; --i) {
        for (int j = game_state[0].size()-1; j >= 0; --j) {
            game_state[i][j] = dut->DataOut;
            dut->DataIn = dut->DataOut;
            dut->clock = 1;
            updateRTL(dut, sim_time, tfp);
            dut->clock = 0;
            updateRTL(dut, sim_time, tfp);

        }
    }
    // Reset shift logic and hold for 1 clock
    dut->Shift = 0;
    dut->clock = 1;
    updateRTL(dut, sim_time, tfp);
    dut->clock = 0;
    updateRTL(dut, sim_time, tfp);
}


// Function to manually calculate the next predicted game state. 
// Used to verify correctness of DUT.
vector<vector<bool>> calc_game_state(const vector<vector<bool>>& current_state) {
    int rows = current_state.size();
    int cols = current_state[0].size();
    
    // Create a new grid to hold the next state
    vector<vector<bool>> next_state(rows, vector<bool>(cols, false));

    // Helper lambda to count the live neighbors of a cell
    auto count_live_neighbors = [&](int row, int col) -> int {
        int live_neighbors = 0;

        // Check all 8 neighbors (diagonals, horizontal, vertical)
        for (int i = -1; i <= 1; ++i) {
            for (int j = -1; j <= 1; ++j) {
                // Skip the center cell itself
                if (i == 0 && j == 0) continue;

                int new_row = row + i;
                int new_col = col + j;

                // Check bounds of the grid
                if (new_row >= 0 && new_row < rows && new_col >= 0 && new_col < cols) {
                    if (current_state[new_row][new_col]) {
                        live_neighbors++;
                    }
                }
            }
        }

        return live_neighbors;
    };

    // Iterate over each cell in the grid
    for (int i = 0; i < rows; ++i) {
        for (int j = 0; j < cols; ++j) {
            int live_neighbors = count_live_neighbors(i, j);

            // Apply the rules of the Game of Life
            if (current_state[i][j]) {
                // Rule 1: A live cell with 2 or 3 live neighbors stays alive
                if (live_neighbors == 2 || live_neighbors == 3) {
                    next_state[i][j] = true;
                } else {
                    next_state[i][j] = false;
                }
            } else {
                // Rule 2: A dead cell with exactly 3 live neighbors becomes alive
                if (live_neighbors == 3) {
                    next_state[i][j] = true;
                } else {
                    next_state[i][j] = false;
                }
            }
        }
    }

    return next_state;
}

int score_game_state(vector<vector<bool>> expected_state, vector<vector<bool>> dut_state) {
    if (expected_state == dut_state) return 1;
    else {
        cout << "ERROR" << endl;
        return 0;
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    VGOL* dut = new VGOL;
    // Parse arguments passed with `-G` flags
    int rows = 30; // Default value
    int columns = 30; // Default value


    VerilatedVcdC* tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open("waveform.vcd");

    dut->Shift = 0;
    dut->NextTimeTick = 0;
    dut->DataIn = 0; // reset all inputs
    // Wait a few clocks
    for (int i=0; i<5; ++i) {
        dut->clock = 1;
        updateRTL(dut, sim_time, tfp);
        dut->clock = 0;
        updateRTL(dut, sim_time, tfp);
    }

    // Run tests
    int t = 0;
    int run = 1;
    while (run) {
        t++;
        // Generate random initial grid state if run=1, if run=2 do special
        vector<vector<bool>> game_state;
        if (run==1) game_state = generate_stimulus(rows, columns);
        else if (run==2) game_state = p46_gun(rows, columns);
       

        // Apply random grid to DUT 
        apply_stimulus(dut, game_state, sim_time, tfp);

        // Buffer to store each iteration's game state
        vector<vector<vector<bool>>> game_states;

        // Let each stimulus run for 200 cycles unless it converges early
        // each cycle check game state and make sure it is correct
        for (int c = 0; c < 200; ++c) {
            // Toggle NextTimeTick for one clock cycle
            dut->NextTimeTick = 1;
            dut->clock = 1;
            updateRTL(dut, sim_time, tfp);
            dut->clock = 0;
            updateRTL(dut, sim_time, tfp);

            // Reset NextTimeTick and stall for one clock
            dut->NextTimeTick = 0;
            dut->clock = 1;
            updateRTL(dut, sim_time, tfp);
            dut->clock = 0;
            updateRTL(dut, sim_time, tfp);

            // Capture output grid
            vector<vector<bool>> game_state_DUT(rows, vector<bool>(columns, 0));
            capture_game_state(dut, game_state_DUT, sim_time, tfp); // capture game state of DUT
            game_states.push_back(game_state_DUT);
            if (game_state_DUT == game_state) {
                cout << "Test#" << t+1 << " converged at iteration #" << c+1 << endl;
                break;
            } // convergence reached, terminate early

            // convergence not reached, check if new game state is correct
            game_state = calc_game_state(game_state); // update expected game state
            if (!score_game_state(game_state_DUT, game_state)) {
                // Error message if incorrect game state
                cout << "On Test#" << t+1 << " Iteration #" << c+1 << endl;
            }
        }
        // After the test case, cycle through the game states in the UI
        run = cycle_game_states(game_states);
    }

    tfp->close();
    delete dut;
    exit(EXIT_SUCCESS);
}


