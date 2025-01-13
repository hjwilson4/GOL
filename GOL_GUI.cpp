#include <vector>
#include <stdlib.h>
#include <iostream>
#include <SFML/Graphics.hpp>
#include <SFML/Window.hpp>
#include <SFML/System.hpp>

using namespace std;

// Function to render the game state grid using SFML
void render_grid(const vector<vector<bool>>& game_state, sf::RenderWindow& window, int cell_size = 30) {
    // Clear the window with white color
    window.clear(sf::Color::White);

    // Get window size
    int window_width = window.getSize().x;
    int window_height = window.getSize().y;

    // Calculate the cell size dynamically to fit the window
    int grid_columns = game_state[0].size();
    int grid_rows = game_state.size();
    int dynamic_cell_size = std::min(window_width / grid_columns, window_height / grid_rows);

    // Calculate the total size of the grid
    int grid_width = grid_columns * dynamic_cell_size;
    int grid_height = grid_rows * dynamic_cell_size;

    // Calculate the position to center the grid
    int offset_x = (window_width - grid_width) / 2;
    int offset_y = (window_height - grid_height) / 2;

    // Draw each cell of the grid
    for (int i = 0; i < game_state.size(); ++i) {
        for (int j = 0; j < game_state[0].size(); ++j) {
            sf::RectangleShape cell(sf::Vector2f(dynamic_cell_size, dynamic_cell_size));
            cell.setPosition(offset_x + j * dynamic_cell_size, offset_y + i * dynamic_cell_size);
            cell.setFillColor(game_state[i][j] ? sf::Color{0, 255, 75, 150} : sf::Color{200, 0, 0, 150});
            cell.setOutlineColor(sf::Color::Black); // Cell outline color
            cell.setOutlineThickness(2); // Cell outline thickness
            window.draw(cell);
        }
    }
}

// Function to cycle through game states with a button press in the UI
int cycle_game_states(const vector<vector<vector<bool>>>& game_states) {
    // Create a window
    sf::RenderWindow window(sf::VideoMode(800, 800), "Game of Life", sf::Style::Close | sf::Style::Resize);

    // Create a next iteration button
    sf::RectangleShape iter_button(sf::Vector2f(200, 50));
    iter_button.setFillColor(sf::Color{0, 150, 255}); // Light blue button
    // Center the button horizontally and place it near the bottom of the screen
    iter_button.setPosition((window.getSize().x - iter_button.getSize().x) / 2, window.getSize().y - iter_button.getSize().y - 20); 

    // Create a skip to new random game button
    sf::RectangleShape next_button(sf::Vector2f(300, 50));
    next_button.setFillColor(sf::Color{0, 150, 255}); // Light blue button
    // Place the button near the top-left of the screen with some padding
    next_button.setPosition(20, 20);

    // Create a skip to new special game button
    sf::RectangleShape cool_button(sf::Vector2f(300, 50));
    cool_button.setFillColor(sf::Color{0, 150, 255}); // Light blue button
    // Place the button near the top-right of the screen with some padding
    cool_button.setPosition(window.getSize().x - cool_button.getSize().x - 20, 20);

    // Pace slider 
    sf::RectangleShape slider_track(sf::Vector2f(10, 300));
    slider_track.setFillColor(sf::Color::Black);
    slider_track.setPosition(window.getSize().x - 30, 100);

    sf::RectangleShape slider_thumb(sf::Vector2f(20, 20));
    slider_thumb.setFillColor(sf::Color::Red);
    slider_thumb.setPosition(window.getSize().x - 35, 100);

    // Load the font
    sf::Font font;
    if (!font.loadFromFile("Anton.ttf")) {
        std::cerr << "Error loading font!" << std::endl;
        return 0; // Exit if font is not found
    }

    // Create and position the text for each button
    sf::Text iterbuttonText("Calc Next Iteration", font, 20);
    sf::Text nextbuttonText("Click for New Random Game", font, 30);
    sf::Text coolbuttonText("Click for Special Game", font, 30);

    // Center the text within each button
    auto centerText = [](sf::Text& text, sf::RectangleShape& button) {
        sf::FloatRect textBounds = text.getLocalBounds();
        text.setOrigin(textBounds.left + textBounds.width / 2.0f, textBounds.top + textBounds.height / 2.0f);
        text.setPosition(button.getPosition().x + button.getSize().x / 2.0f, button.getPosition().y + button.getSize().y / 2.0f);
    };

    centerText(iterbuttonText, iter_button);
    centerText(nextbuttonText, next_button);
    centerText(coolbuttonText, cool_button);

    int current_state_index = 0;
    bool isButtonHeld = false;
    sf::Clock holdClock;
    sf::Clock clickClock;

    int simulation_pace = 50;
    bool isSliderHeld = false;


    // Main UI loop
    while (window.isOpen()) {
        sf::Event event;

        while (window.pollEvent(event)) {
            if (event.type == sf::Event::Closed) {
                window.close();
                return 0;
            }

            if (event.type == sf::Event::MouseButtonPressed && event.mouseButton.button == sf::Mouse::Left) {
                if (iter_button.getGlobalBounds().contains(event.mouseButton.x, event.mouseButton.y)) {
                    isButtonHeld = true;
                    holdClock.restart(); // start hold clock timer
                    clickClock.restart(); // start click delay timer
                }

                else if (next_button.getGlobalBounds().contains(event.mouseButton.x, event.mouseButton.y)) {
                    window.close();
                    return 1;
                }

                else if (cool_button.getGlobalBounds().contains(event.mouseButton.x, event.mouseButton.y)) {
                    window.close();
                    return 2; // tell main() to produce a special starting state
                }
                else if (slider_thumb.getGlobalBounds().contains(event.mouseButton.x, event.mouseButton.y)) {
                    isSliderHeld = true;
                }
            }

            if (event.type == sf::Event::MouseButtonReleased && event.mouseButton.button == sf::Mouse::Left) {
                isSliderHeld = false;
                if (iter_button.getGlobalBounds().contains(event.mouseButton.x, event.mouseButton.y)) {
                    isButtonHeld = false;
                    if (clickClock.getElapsedTime().asMilliseconds() < 500) {
                        // if button was held for less than 500 ms, it was a click rather than a hold, update state
                        // by one iteration.
                        current_state_index++;
                        if (current_state_index >= game_states.size()) {
                            current_state_index = 0;
                        }
                    }
                }
            }

            if (event.type == sf::Event::Resized) {
                sf::FloatRect visibleArea(0, 0, event.size.width, event.size.height);
                window.setView(sf::View(visibleArea));

                // Update button positions and sizes
                iter_button.setSize(sf::Vector2f(event.size.width * 0.25f, event.size.height * 0.06f));
                iter_button.setPosition((event.size.width - iter_button.getSize().x) / 2, event.size.height - iter_button.getSize().y - 20);

                // Update the size and position of next_button
                next_button.setSize(sf::Vector2f(event.size.width * 0.375f, event.size.height * 0.06f));
                next_button.setPosition(20, 20);

                // Update the size and position of cool_button
                cool_button.setSize(sf::Vector2f(event.size.width * 0.375f, event.size.height * 0.06f));
                cool_button.setPosition(event.size.width - cool_button.getSize().x - 20, 20);

                slider_track.setSize(sf::Vector2f(10, 300));
                slider_track.setPosition(event.size.width - 30, 100);
                slider_thumb.setPosition(event.size.width - 35, slider_thumb.getPosition().y);

                float iterbuttonFontSize = iter_button.getSize().y * 0.5f;
                float nextbuttonFontSize = next_button.getSize().y * 0.5f;
                float coolbuttonFontSize = cool_button.getSize().y * 0.5f;
                iterbuttonText.setCharacterSize(iterbuttonFontSize);
                nextbuttonText.setCharacterSize(nextbuttonFontSize);
                coolbuttonText.setCharacterSize(coolbuttonFontSize);

                // Update text positions
                // Update text positions
                centerText(iterbuttonText, iter_button);
                centerText(nextbuttonText, next_button);
                centerText(coolbuttonText, cool_button);
            }

            if (event.type == sf::Event::MouseMoved && isSliderHeld) {
                int new_y = event.mouseMove.y;
                new_y = std::max(100, std::min(400, new_y));
                slider_thumb.setPosition(window.getSize().x - 35, new_y);

                float position_ratio = static_cast<float>(new_y - 100) / (300);
                simulation_pace = 20 + static_cast<int>(position_ratio * (500 - 20));
            }

        }

        if (isButtonHeld && clickClock.getElapsedTime().asMilliseconds() >= 500 && holdClock.getElapsedTime().asMilliseconds() >= simulation_pace) {
            current_state_index++;
            if (current_state_index >= game_states.size()) {
                current_state_index = 0;
            }
            holdClock.restart();
        }

        window.clear();
        render_grid(game_states[current_state_index], window); // Render the current game state
        window.draw(iter_button);
        window.draw(iterbuttonText);
        window.draw(next_button);
        window.draw(nextbuttonText);
        window.draw(cool_button);
        window.draw(coolbuttonText);
        window.draw(slider_track);
        window.draw(slider_thumb);
        window.display();
    }

    return 1;
}