import sys
import os
from src.core.orchestrator import run_mission
if __name__ == "__main__":
    if len(sys.argv) < 2: 
        print("Usage: python main.py 'Objective'")
        sys.exit(1)
    os.makedirs("workspace", exist_ok=True)
    print(run_mission(sys.argv[1]))
