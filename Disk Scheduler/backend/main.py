from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Dict, Any
import algorithms

app = FastAPI(title="Disk Scheduling API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class DiskRequest(BaseModel):
    requests: List[int] = Field(..., json_schema_extra={"example": [98, 183, 37, 122, 14, 124, 65, 67]})
    initial_head: int = Field(..., json_schema_extra={"example": 53})
    disk_size: int = Field(200, json_schema_extra={"example": 200})
    direction: str = Field("left", pattern="^(left|right)$")
    algorithm: str = Field("FCFS", pattern="^(FCFS|SSTF|SCAN|C-SCAN|LOOK|C-LOOK)$")


def run_algo(algo: str, requests: List[int], initial_head: int, disk_size: int, direction: str) -> Dict[str, Any]:
    algo_upper = algo.upper()
    if algo_upper == "FCFS":
        return algorithms.solve_fcfs(requests, initial_head)
    elif algo_upper == "SSTF":
        return algorithms.solve_sstf(requests, initial_head)
    elif algo_upper == "SCAN":
        return algorithms.solve_scan(requests, initial_head, disk_size, direction)
    elif algo_upper == "C-SCAN":
        return algorithms.solve_cscan(requests, initial_head, disk_size, direction)
    elif algo_upper == "LOOK":
        return algorithms.solve_look(requests, initial_head, direction)
    elif algo_upper == "C-LOOK":
        return algorithms.solve_clook(requests, initial_head, direction)
    else:
        raise HTTPException(status_code=400, detail=f"Invalid algorithm: {algo}")


@app.post("/api/simulate")
def simulate_disk_scheduling(data: DiskRequest):
    if data.disk_size <= 0:
        raise HTTPException(status_code=400, detail="Disk size must be greater than 0.")
    for r in data.requests:
        if r < 0 or r >= data.disk_size:
            raise HTTPException(status_code=400, detail=f"Request {r} is out of disk bounds (0 to {data.disk_size - 1}).")
    if data.initial_head < 0 or data.initial_head >= data.disk_size:
        raise HTTPException(status_code=400, detail="Initial head position is out of bounds.")

    res = run_algo(data.algorithm, data.requests, data.initial_head, data.disk_size, data.direction)

    steps = []
    seq = res["sequence"]
    for i in range(1, len(seq)):
        steps.append({
            "from": seq[i-1],
            "to": seq[i],
            "distance": abs(seq[i] - seq[i-1])
        })

    return {
        "algorithm": data.algorithm.upper(),
        "sequence": seq,
        "total_movement": res["total_movement"],
        "steps": steps
    }


@app.post("/api/compare")
def compare_disk_scheduling(data: DiskRequest):
    if data.disk_size <= 0:
        raise HTTPException(status_code=400, detail="Disk size must be greater than 0.")
    for r in data.requests:
        if r < 0 or r >= data.disk_size:
            raise HTTPException(status_code=400, detail=f"Request {r} is out of disk bounds (0 to {data.disk_size - 1}).")
    if data.initial_head < 0 or data.initial_head >= data.disk_size:
        raise HTTPException(status_code=400, detail="Initial head position is out of bounds.")

    all_algos = ["FCFS", "SSTF", "SCAN", "C-SCAN", "LOOK", "C-LOOK"]
    comparison = {}

    for algo in all_algos:
        res = run_algo(algo, data.requests, data.initial_head, data.disk_size, data.direction)
        seq = res["sequence"]
        steps = [
            {"from": seq[i-1], "to": seq[i], "distance": abs(seq[i] - seq[i-1])}
            for i in range(1, len(seq))
        ]
        comparison[algo] = {
            "algorithm": algo,
            "sequence": seq,
            "total_movement": res["total_movement"],
            "steps": steps
        }

    return comparison
