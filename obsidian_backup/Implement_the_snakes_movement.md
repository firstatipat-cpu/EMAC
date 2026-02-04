# Implement the snake's movement logic.
```python
def snake_movement(initial_position, direction, grid_size):
    """Simulates the movement of a snake on a grid."""
    snake = [initial_position]
    score = 0
    food = (0, 0)
    visited = set()  # Keep track of visited cells

    def check_collision(new_head):
        if new_head in visited or new_head[0] < 0 or new_head[0] >= grid_size or new_head[1] < 0 or new_head[1] >= grid_size:
            return True
        return False

    def move():
        nonlocal score
        head = snake[0]
        new_head = (head[0] + direction[0], head[1] + direction[1])

        if check_collision(new_head):
            return False  # Game over

        snake.insert(0, new_head)
        if new_head == food:
            score += 1
            food = ( (food[0] + 1) % grid_size, food[1]) if food[0] < grid_size -1 else ((food[0] - 1) % grid_size, food[1]) 
        else:
            snake.pop()
        visited.add(new_head) #Mark new head as visited
        return True

    return move
```
> 