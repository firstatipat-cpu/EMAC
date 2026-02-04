# Analyze the requirements: The function needs to take two fractions as input and return their sum as a fraction.  Consider the common denominator, if needed.
```python
def sum_fractions(f1, f2):
    """Returns the sum of two fractions.

    Args:
        f1 (tuple): A tuple representing the first fraction (numerator, denominator).
        f2 (tuple): A tuple representing the second fraction (numerator, denominator).

    Returns:
        tuple: A tuple representing the sum of the two fractions (numerator, denominator).
    """
    num1, den1 = f1
    num2, den2 = f2
    new_den = den1 * den2
    new_num = num1 * den2 + num2 * den1
    return (new_num, new_den)
```
> 