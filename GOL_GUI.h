#include <vector>
#include <SFML/Graphics.hpp>
#include <SFML/Window.hpp>
#include <SFML/System.hpp>

using namespace std;

void render_grid(const vector<vector<bool>>& game_state, sf::RenderWindow& window, int cell_size = 30);
int cycle_game_states(const vector<vector<vector<bool>>>& game_states);
