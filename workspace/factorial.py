import math

def factorial(n):
    if n == 0:
        return 1
    else:
        return math.factorial(n)

if __name__ == "__main__":
    n = 100
    result = factorial(n)
    print(f"{n}! = {result}")