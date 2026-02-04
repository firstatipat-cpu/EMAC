def fibonacci(n):
  if n == 0:
    return 1
  elif n == 1:
    return 1
  else:
    a, b = 0, 1
    for _ in range(n):
      a, b = b, a + b
    return a