import asyncio
import json
import time
from fastapi import FastAPI, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse

app = FastAPI(title="N-Queens Solver API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SOLVER_PATH = "./nqueens_solver"

async def stream_solver_output(n: int):
    """Stream output from the C solver as SSE events."""
    process = await asyncio.create_subprocess_exec(
        SOLVER_PATH, str(n),
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )

    solutions_count = 0

    try:
        while True:
            line = await process.stdout.readline()
            if not line:
                break

            line = line.decode().strip()
            if line:
                # Track solutions for completion event
                if line.startswith('{"type":"SOLUTION_FOUND"'):
                    solutions_count += 1
                # Yield as SSE format
                yield f"data: {line}\n\n"

        # Wait for process to complete
        await process.wait()

        # Send completion event
        yield f"data: {{\"type\":\"COMPLETE\",\"solutions\":{solutions_count}}}\n\n"
    except asyncio.CancelledError:
        # Client disconnected, terminate process
        process.terminate()
        await process.wait()
        raise
    finally:
        if process.returncode is None:
            process.terminate()
            await process.wait()

@app.get("/health")
async def health_check():
    return {"status": "ok"}

@app.get("/api/stream-solve/{n}")
async def stream_solve(n: int):
    if n < 4 or n > 12:
        raise HTTPException(status_code=400, detail="n must be between 4 and 12")

    return StreamingResponse(
        stream_solver_output(n),
        media_type="text/event-stream"
    )

@app.post("/api/benchmark")
async def benchmark(n: int = 8):
    if n < 1 or n > 12:
        raise HTTPException(status_code=400, detail="n must be between 1 and 12")

    start_time = time.perf_counter()
    process = await asyncio.create_subprocess_exec(
        SOLVER_PATH, str(n),
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )

    solutions = 0
    while True:
        line = await process.stdout.readline()
        if not line:
            break
        line = line.decode().strip()
        if line.startswith('{"type":"SOLUTION_FOUND"'):
            solutions += 1

    await process.wait()
    elapsed = time.perf_counter() - start_time

    return {
        "n": n,
        "solutions": solutions,
        "time_seconds": elapsed,
        "time_ms": elapsed * 1000
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)