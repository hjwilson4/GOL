#include "VGOL.h"
#include <verilated.h>
#include <stdlib.h>
#include <iostream>
#include <vector>
#include <random>
#if VM_TRACE
#include "verilated_vcd_c.h"
#endif
#include <SFML/Graphics.hpp>
#include <SFML/Window.hpp>
#include <SFML/System.hpp>

using namespace std;

#define NUM_TESTS 5    // Number of random test cases
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

// Function to capture DUT output grid
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

// Function to render the game state grid using SFML
void render_grid(const vector<vector<bool>>& game_state, sf::RenderWindow& window, int cell_size = 30) {
    // Clear the window with white color
    window.clear(sf::Color::White);

    // Calculate the total size of the grid
    int grid_width = game_state[0].size() * cell_size;
    int grid_height = game_state.size() * cell_size;

    // Calculate the position to center the grid
    int window_width = window.getSize().x;
    int window_height = window.getSize().y;
    int offset_x = (window_width - grid_width) / 2;
    int offset_y = (window_height - grid_height) / 2;

    // Draw each cell of the grid
    for (int i = 0; i < game_state.size(); ++i) {
        for (int j = 0; j < game_state[0].size(); ++j) {
            sf::RectangleShape cell(sf::Vector2f(cell_size, cell_size));
            cell.setPosition(offset_x + j * cell_size, offset_y + i * cell_size);
            if (game_state[i][j]) {
                cell.setFillColor(sf::Color{0, 255, 75, 150}); // Alive cell light green

            } else {
                cell.setFillColor(sf::Color{200, 0, 0, 150}); // Dead cell light red
            }
            cell.setOutlineColor(sf::Color::Black); // Cell outline color
            cell.setOutlineThickness(2); // Cell outline thickness
            window.draw(cell);
        }
    }
}

// Function to cycle through game states with a button press in the UI
bool cycle_game_states(const vector<vector<vector<bool>>>& game_states) {
    // Create a window
    sf::RenderWindow window(sf::VideoMode(800, 800), "Game of Life", sf::Style::Close | sf::Style::Resize);

    // Create a next iteration button
    sf::RectangleShape iter_button(sf::Vector2f(200, 50));
    iter_button.setFillColor(sf::Color{0, 150, 255});
    // Center the button horizontally and place it near the bottom of the screen
    iter_button.setPosition((window.getSize().x - iter_button.getSize().x) / 2, window.getSize().y - iter_button.getSize().y - 20); 

    // Create a skip to new game button
    sf::RectangleShape next_button(sf::Vector2f(300, 50));
    next_button.setFillColor(sf::Color{0, 150, 255});
    // Center the button horizontally and place it near the top of the screen
    next_button.setPosition((window.getSize().x - next_button.getSize().x) / 2, 20); 


    // Load the font
    sf::Font font;
    if (!font.loadFromFile("Anton.ttf")) {
        std::cerr << "Error loading font!" << std::endl;
        return false; // Exit if font is not found
    }

    // Create text for the iteration button and set the font
    sf::Text iterbuttonText;
    iterbuttonText.setString("Calc Next Iteration");
    iterbuttonText.setFont(font);
    iterbuttonText.setCharacterSize(20);
    iterbuttonText.setFillColor(sf::Color::Black);

    // Create text for the skip test button and set the font
    sf::Text nextbuttonText;
    nextbuttonText.setString("Click for New Game");
    nextbuttonText.setFont(font);
    nextbuttonText.setCharacterSize(30);
    nextbuttonText.setFillColor(sf::Color::Black);

    // Set the origin of the text to its center for proper centering
    sf::FloatRect iter_textBounds = iterbuttonText.getLocalBounds();
    iterbuttonText.setOrigin(iter_textBounds.left + iter_textBounds.width / 2.0f, iter_textBounds.top + iter_textBounds.height / 2.0f);

    // Center the text in the button
    iterbuttonText.setPosition(
        iter_button.getPosition().x + iter_button.getSize().x / 2.0f, 
        iter_button.getPosition().y + iter_button.getSize().y / 2.0f
    );

    // Set the origin of the text to its center for proper centering
    sf::FloatRect next_textBounds = nextbuttonText.getLocalBounds();
    nextbuttonText.setOrigin(next_textBounds.left + next_textBounds.width / 2.0f, next_textBounds.top + next_textBounds.height / 2.0f);

    // Center the text in the button
    nextbuttonText.setPosition(
        next_button.getPosition().x + next_button.getSize().x / 2.0f, 
        next_button.getPosition().y + next_button.getSize().y / 2.0f
    );

    int current_state_index = 0;

    // Main UI loop
    while (window.isOpen()) {
        sf::Event event;

        while (window.pollEvent(event)) {
            if (event.type == sf::Event::Closed) {
                window.close();
                return false;
            }

            if (event.type == sf::Event::MouseButtonPressed && event.mouseButton.button == sf::Mouse::Left) {
                if (iter_button.getGlobalBounds().contains(event.mouseButton.x, event.mouseButton.y)) {
                    current_state_index++;
                    if (current_state_index >= game_states.size()) {
                        current_state_index = 0; // Loop back to the first state
                    }
                }

                else if (next_button.getGlobalBounds().contains(event.mouseButton.x, event.mouseButton.y)) {
                    window.close();
                    return true;
                }
            }
        }

        window.clear();
        render_grid(game_states[current_state_index], window); // Render the current game state
        window.draw(iter_button);
        window.draw(iterbuttonText);
        window.draw(next_button);
        window.draw(nextbuttonText);
        window.display();
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    VGOL* dut = new VGOL;
    // Parse arguments passed with `-G` flags
    int rows = 6; // Default value
    int columns = 10; // Default value


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
    bool run = true;
    while (run) {
        t++;
        // Generate random initial grid state
        vector<vector<bool>> game_state = generate_stimulus(rows, columns);

        // Apply random grid to DUT
        apply_stimulus(dut, game_state, sim_time, tfp);

        // Buffer to store each iteration's game state
        vector<vector<vector<bool>>> game_states;

        // Let each stimulus run for 50 cycles unless it converges early
        // each cycle check game state and make sure it is correct
        for (int c = 0; c < 50; ++c) {
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


