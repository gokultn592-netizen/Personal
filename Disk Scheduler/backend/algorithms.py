from typing import List, Dict, Any

def solve_fcfs(requests: List[int], initial_head: int) -> Dict[str, Any]:
    path = [initial_head] + requests
    total_movement = sum(abs(path[i] - path[i - 1]) for i in range(1, len(path)))
    return {"sequence": path, "total_movement": total_movement}


def solve_sstf(requests: List[int], initial_head: int) -> Dict[str, Any]:
    pending = list(requests)
    curr = initial_head
    path = [curr]
    total_movement = 0

    while pending:
        closest = min(pending, key=lambda x: abs(x - curr))
        total_movement += abs(closest - curr)
        curr = closest
        path.append(curr)
        pending.remove(curr)

    return {"sequence": path, "total_movement": total_movement}


def solve_scan(requests: List[int], initial_head: int, disk_size: int, direction: str) -> Dict[str, Any]:
    left = sorted([r for r in requests if r < initial_head], reverse=True)
    right = sorted([r for r in requests if r >= initial_head])
    
    path = [initial_head]
    if direction == "left":
        path.extend(left)
        if 0 not in path:
            path.append(0)  # SCAN hits boundary
        path.extend(right)
    else:
        path.extend(right)
        if (disk_size - 1) not in path:
            path.append(disk_size - 1)
        path.extend(left)

    total_movement = sum(abs(path[i] - path[i - 1]) for i in range(1, len(path)))
    return {"sequence": path, "total_movement": total_movement}


def solve_cscan(requests: List[int], initial_head: int, disk_size: int, direction: str) -> Dict[str, Any]:
    left = sorted([r for r in requests if r < initial_head])
    right = sorted([r for r in requests if r >= initial_head])
    
    path = [initial_head]
    if direction == "right":
        path.extend(right)
        path.append(disk_size - 1)
        path.append(0)
        path.extend(left)
    else:
        path.extend(sorted(left, reverse=True))
        path.append(0)
        path.append(disk_size - 1)
        path.extend(sorted(right, reverse=True))

    total_movement = sum(abs(path[i] - path[i - 1]) for i in range(1, len(path)))
    return {"sequence": path, "total_movement": total_movement}


def solve_look(requests: List[int], initial_head: int, direction: str) -> Dict[str, Any]:
    left = sorted([r for r in requests if r < initial_head], reverse=True)
    right = sorted([r for r in requests if r >= initial_head])
    
    path = [initial_head]
    if direction == "left":
        path.extend(left)
        path.extend(right)
    else:
        path.extend(right)
        path.extend(left)

    total_movement = sum(abs(path[i] - path[i - 1]) for i in range(1, len(path)))
    return {"sequence": path, "total_movement": total_movement}


def solve_clook(requests: List[int], initial_head: int, direction: str) -> Dict[str, Any]:
    left = sorted([r for r in requests if r < initial_head])
    right = sorted([r for r in requests if r >= initial_head])
    
    path = [initial_head]
    if direction == "right":
        path.extend(right)
        path.extend(left)
    else:
        path.extend(sorted(left, reverse=True))
        path.extend(sorted(right, reverse=True))

    total_movement = sum(abs(path[i] - path[i - 1]) for i in range(1, len(path)))
    return {"sequence": path, "total_movement": total_movement}
