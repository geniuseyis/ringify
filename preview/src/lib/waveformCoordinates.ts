export function timeAtPosition(clientX: number, left: number, width: number, duration: number) {
  return Math.max(0, Math.min(duration, (clientX - left) / Math.max(1, width) * duration))
}

// The adjacent IEEE-754 value matches Swift Double.nextUp/nextDown. Only
// used at a duration limit; ordinary trim timecodes are never quantized.
function adjacentTime(time: number, increase: boolean) {
  if (time === 0) return increase ? Number.MIN_VALUE : -Number.MIN_VALUE
  const view = new DataView(new ArrayBuffer(8))
  view.setFloat64(0, time)
  const bits = view.getBigUint64(0)
  view.setBigUint64(0, bits + ((time > 0) === increase ? 1n : -1n))
  return view.getFloat64(0)
}

export function trimBoundary(kind: 'start' | 'end', time: number, start: number, end: number, duration: number): [number, number] {
  if (!Number.isFinite(time)) return [start, end]
  // Snap only near actual source edges, then apply the existing 1–29s limits.
  // Snapping cannot override the valid selection range.
  if (Math.abs(time) <= 0.06) time = 0
  else if (Math.abs(duration - time) <= 0.06) time = duration
  const next: [number, number] = kind === 'start'
    ? [Math.max(0, end - 29, Math.min(time, end - 1)), end]
    : [start, Math.min(duration, start + 29, Math.max(time, start + 1))]
  const length = next[1] - next[0]
  if (length > 29) next[kind === 'start' ? 0 : 1] = adjacentTime(next[kind === 'start' ? 0 : 1], kind === 'start')
  else if (length < 1) next[kind === 'start' ? 0 : 1] = adjacentTime(next[kind === 'start' ? 0 : 1], kind === 'end')
  return next
}
