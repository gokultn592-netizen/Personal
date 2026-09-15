// Client-side JavaScript implementations of Disk Scheduling Algorithms

export function solveFCFS(requests, initialHead) {
  const path = [initialHead, ...requests];
  let totalMovement = 0;
  for (let i = 1; i < path.length; i++) {
    totalMovement += Math.abs(path[i] - path[i - 1]);
  }
  return { sequence: path, total_movement: totalMovement };
}

export function solveSSTF(requests, initialHead) {
  const pending = [...requests];
  let curr = initialHead;
  const path = [curr];
  let totalMovement = 0;

  while (pending.length > 0) {
    let minDiff = Infinity;
    let closestIndex = -1;

    for (let i = 0; i < pending.length; i++) {
      const diff = Math.abs(pending[i] - curr);
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }

    const closest = pending[closestIndex];
    totalMovement += Math.abs(closest - curr);
    curr = closest;
    path.push(curr);
    pending.splice(closestIndex, 1);
  }

  return { sequence: path, total_movement: totalMovement };
}

export function solveSCAN(requests, initialHead, diskSize, direction) {
  const left = requests.filter((r) => r < initialHead).sort((a, b) => b - a);
  const right = requests.filter((r) => r >= initialHead).sort((a, b) => a - b);

  const path = [initialHead];
  if (direction === 'left') {
    path.push(...left);
    if (!path.includes(0)) {
      path.push(0); // SCAN hits boundary
    }
    path.push(...right);
  } else {
    path.push(...right);
    if (!path.includes(diskSize - 1)) {
      path.push(diskSize - 1);
    }
    path.push(...left);
  }

  let totalMovement = 0;
  for (let i = 1; i < path.length; i++) {
    totalMovement += Math.abs(path[i] - path[i - 1]);
  }
  return { sequence: path, total_movement: totalMovement };
}

export function solveCSCAN(requests, initialHead, diskSize, direction) {
  const left = requests.filter((r) => r < initialHead);
  const right = requests.filter((r) => r >= initialHead);

  const path = [initialHead];
  if (direction === 'right') {
    path.push(...right.sort((a, b) => a - b));
    path.push(diskSize - 1);
    path.push(0);
    path.push(...left.sort((a, b) => a - b));
  } else {
    path.push(...left.sort((a, b) => b - a));
    path.push(0);
    path.push(diskSize - 1);
    path.push(...right.sort((a, b) => b - a));
  }

  let totalMovement = 0;
  for (let i = 1; i < path.length; i++) {
    totalMovement += Math.abs(path[i] - path[i - 1]);
  }
  return { sequence: path, total_movement: totalMovement };
}

export function solveLOOK(requests, initialHead, diskSize, direction) {
  const left = requests.filter((r) => r < initialHead).sort((a, b) => b - a);
  const right = requests.filter((r) => r >= initialHead).sort((a, b) => a - b);

  const path = [initialHead];
  if (direction === 'left') {
    path.push(...left);
    path.push(...right);
  } else {
    path.push(...right);
    path.push(...left);
  }

  let totalMovement = 0;
  for (let i = 1; i < path.length; i++) {
    totalMovement += Math.abs(path[i] - path[i - 1]);
  }
  return { sequence: path, total_movement: totalMovement };
}

export function solveCLOOK(requests, initialHead, diskSize, direction) {
  const left = requests.filter((r) => r < initialHead);
  const right = requests.filter((r) => r >= initialHead);

  const path = [initialHead];
  if (direction === 'right') {
    path.push(...right.sort((a, b) => a - b));
    path.push(...left.sort((a, b) => a - b));
  } else {
    path.push(...left.sort((a, b) => b - a));
    path.push(...right.sort((a, b) => b - a));
  }

  let totalMovement = 0;
  for (let i = 1; i < path.length; i++) {
    totalMovement += Math.abs(path[i] - path[i - 1]);
  }
  return { sequence: path, total_movement: totalMovement };
}

export function simulateDiskScheduling({ requests, initial_head, disk_size, direction, algorithm }) {
  const algo = algorithm.toUpperCase();
  let res;

  switch (algo) {
    case 'FCFS':
      res = solveFCFS(requests, initial_head);
      break;
    case 'SSTF':
      res = solveSSTF(requests, initial_head);
      break;
    case 'SCAN':
      res = solveSCAN(requests, initial_head, disk_size, direction);
      break;
    case 'C-SCAN':
      res = solveCSCAN(requests, initial_head, disk_size, direction);
      break;
    case 'LOOK':
      res = solveLOOK(requests, initial_head, disk_size, direction);
      break;
    case 'C-LOOK':
      res = solveCLOOK(requests, initial_head, disk_size, direction);
      break;
    default:
      throw new Error(`Invalid algorithm: ${algorithm}`);
  }

  const steps = [];
  const seq = res.sequence;
  for (let i = 1; i < seq.length; i++) {
    steps.push({
      from: seq[i - 1],
      to: seq[i],
      distance: Math.abs(seq[i] - seq[i - 1])
    });
  }

  return {
    algorithm: algo,
    sequence: seq,
    total_movement: res.total_movement,
    steps
  };
}

export function compareDiskScheduling({ requests, initial_head, disk_size, direction }) {
  const allAlgos = ['FCFS', 'SSTF', 'SCAN', 'C-SCAN', 'LOOK', 'C-LOOK'];
  const comparison = {};

  for (const algo of allAlgos) {
    comparison[algo] = simulateDiskScheduling({
      requests,
      initial_head,
      disk_size,
      direction,
      algorithm: algo
    });
  }

  return comparison;
}
