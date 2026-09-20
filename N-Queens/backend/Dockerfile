FROM --platform=linux/amd64 python:3.11-slim

RUN apt-get update && apt-get install -y gcc libc6-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY solver.c Makefile requirements.txt ./
COPY main.py ./

RUN gcc -O3 -std=c99 solver.c -o nqueens_solver
RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
