CC = gcc
CFLAGS = -O3 -std=c99 -Wall -Wextra
TARGET = nqueens_solver
SRC = solver.c

.PHONY: build clean

build: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(SRC) -o $(TARGET)

clean:
	rm -f $(TARGET)