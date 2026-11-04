export function timeAtPosition(clientX: number, left: number, width: number, duration: number) {
  return Math.max(0, Math.min(duration, (clientX - left) / Math.max(1, width) * duration))
}

export function trimBoundary(kind: 'start' | 'end', time: number, start: number, end: number, duration: number): [number, number] {
  if (kind === 'start') return [Math.max(0, end - 29, Math.min(time, end - 1)), end]
  return [start, Math.min(duration, start + 29, Math.max(time, start + 1))]
}
