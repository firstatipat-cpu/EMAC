# Implement functions for addition, subtraction, multiplication, and division to handle decimal numbers.
```python
def add(x, y):
    return float(x) + float(y)
def subtract(x, y):
    return float(x) - float(y)
def multiply(x, y):
    return float(x) * float(y)
def divide(x, y):
    if y == 0:
        return "Error: Division by zero"
    else:
        return float(x) / float(y)

# Example usage
num1 = 10.5
num2 = 5.2

print(f"Addition: {add(num1, num2)}")
print(f"Subtraction: {subtract(num1, num2)}")
print(f"Multiplication: {multiply(num1, num2)}")
print(f"Division: {divide(num1, num2)}")

# Example with division by zero
print(f"Division by zero: {divide(num1, 0)}")
```
> 