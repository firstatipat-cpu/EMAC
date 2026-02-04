# Test the implemented functions with various decimal inputs.
```python
import decimal

def calculate_average(numbers):
  """Calculates the average of a list of decimal numbers."""
  if not numbers:
    return Decimal(0)
  total = sum(numbers)
  return total / Decimal(len(numbers))

if __name__ == '__main__':
  # Example usage with decimal numbers
  numbers1 = [decimal.Decimal('1.5'), decimal.Decimal('2.5'), decimal.Decimal('3.5')]
  average1 = calculate_average(numbers1)
  print(f"Average of {numbers1}: {average1}")

  numbers2 = [decimal.Decimal('1'), decimal.Decimal('2'), decimal.Decimal('3')]
  average2 = calculate_average(numbers2)
  print(f"Average of {numbers2}: {average2}")

  numbers3 = [decimal.Decimal('0.1'), decimal.Decimal('0.2'), decimal.Decimal('0.3')]
  average3 = calculate_average(numbers3)
  print(f"Average of {numbers3}: {average3}")

  numbers4 = []
  average4 = calculate_average(numbers4)
  print(f"Average of {numbers4}: {average4}")
```
> 