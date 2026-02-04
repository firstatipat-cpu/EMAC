from pydantic import BaseModel
from typing import List, Optional
class Step(BaseModel):
    id: int
    description: str
    tool_needed: Optional[str] = None
class Plan(BaseModel):
    goal_analysis: str
    steps: List[Step]
class CodeOutput(BaseModel):
    filename: str
    code: str
    dependencies: List[str] = []
class Critique(BaseModel):
    is_passing: bool
    feedback: str
    suggested_fix: Optional[str] = None
class AnalystResult(BaseModel):
    root_cause: str
    lesson_learned: str
