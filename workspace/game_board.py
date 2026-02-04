def create_game_board(rows, cols):
    """Creates a game board with the specified dimensions."""
    board = [['.' for _ in range(cols)] for _ in range(rows)]
    return board

def print_game_board(board):
    """Prints the game board to the console."""
    for row in board:
        print(' '.join(row))

if __name__ == '__main__':
    rows = 5
    cols = 5
    game_board = create_game_board(rows, cols)
    print_game_board(game_board)