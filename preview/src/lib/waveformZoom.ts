export function pinchZoom(origin: number, originalDistance: number, distance: number) {
  const initial = Number.isFinite(origin) ? Math.min(3, Math.max(1, origin)) : 1
  if (!Number.isFinite(originalDistance) || !Number.isFinite(distance) || originalDistance <= 0 || distance <= 0) return initial
  return Math.max(1, Math.min(3, initial * Math.min(3, distance / originalDistance)))
}
