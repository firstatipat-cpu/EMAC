# python functions decimal
```python
def decimal(x):
  """Converts a decimal number to a list of digits."""
  if not isinstance(x, (int, float)): 
    raise TypeError("Input must be a number")
  if x < 0:
    raise ValueError("Input must be non-negative")
  digits = []
  while x > 0:
    digits.insert(0, x % 10)
    x //= 10
  return digits

# Example Usage
if __name__ == '__main__':
  num = 12345
  result = decimal(num)
  print(f"Decimal representation of {num} is: {result}")

  num = 9876543210
  result = decimal(num)
  print(f"Decimal representation of {num} is: {result}")

  try:
    result = decimal("abc")
    print(result)
  except TypeError as e:
    print(e)

  try:
    result = decimal(-10)
    print(result)
  except ValueError as e:
    print(e)
```
> 