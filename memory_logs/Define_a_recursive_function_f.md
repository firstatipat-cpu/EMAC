---
created: 2026-01-26 06:32
tags: #EMACS #Skill
---
# 🧠 Skill: Define a recursive function `factorial(n)` that calculates the factorial of a non-negative integer `n`.
### 📂 `factorial.py`
```python
def factorial(n):
  if n == 0:
    return 1
  else:
    return n * factorial(n-1)


# Example usage
if __name__ == '__main__':
  num = 5
  result = factorial(num)
  print(f'The factorial of {num} is {result}')
```
> **Lesson:** Success
