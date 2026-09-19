#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#define MAX_N 12

int board[MAX_N];
int n;
int solutions_found = 0;

/* Check if a queen can be placed at (row, col) */
bool is_safe(int row, int col) {
    for (int i = 0; i < row; i++) {
        if (board[i] == col) {
            printf("{\"type\":\"CONFLICT\",\"row\":%d,\"col\":%d,\"attackerRow\":%d,\"attackerCol\":%d}\n", row, col, i, board[i]);
            fflush(stdout);
            return false;
        }
        if (abs(board[i] - col) == abs(i - row)) {
            printf("{\"type\":\"CONFLICT\",\"row\":%d,\"col\":%d,\"attackerRow\":%d,\"attackerCol\":%d}\n", row, col, i, board[i]);
            fflush(stdout);
            return false;
        }
    }
    return true;
}

/* Recursive backtracking solver */
void solve(int row) {
    if (row == n) {
        /* Found a complete solution */
        printf("{\"type\":\"SOLUTION_FOUND\",\"board\":[");
        for (int i = 0; i < n; i++) {
            if (i > 0) printf(",");
            printf("%d", board[i]);
        }
        printf("]}\n");
        fflush(stdout);
        solutions_found++;
        return;
    }

    for (int col = 0; col < n; col++) {
        printf("{\"type\":\"MOVE_TRY\",\"row\":%d,\"col\":%d}\n", row, col);
        fflush(stdout);

        if (is_safe(row, col)) {
            board[row] = col;
            printf("{\"type\":\"PLACE_BEACON\",\"row\":%d,\"col\":%d}\n", row, col);
            fflush(stdout);

            solve(row + 1);

            printf("{\"type\":\"REMOVE_BEACON\",\"row\":%d,\"col\":%d}\n", row, col);
            fflush(stdout);
        }
    }
}

int main(int argc, char *argv[]) {
    if (argc > 1) {
        n = atoi(argv[1]);
    } else {
        n = 4;
    }

    if (n < 1 || n > MAX_N) {
        fprintf(stderr, "Error: n must be between 1 and %d\n", MAX_N);
        return 1;
    }

    solve(0);
    return 0;
}