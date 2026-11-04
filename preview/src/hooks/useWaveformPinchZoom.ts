import {useEffect, useLayoutEffect, useRef, type PointerEvent, type RefObject} from 'react'
import {pinchZoom} from '../lib/waveformZoom'

type Point = {x: number; y: number}
type Options = {
  viewport: RefObject<HTMLDivElement | null>
  track: RefObject<HTMLDivElement | null>
  zoom: number
  onZoomChange?: (zoom: number) => void
  enabled: boolean
}

export function useWaveformPinchZoom({viewport, track, zoom, onZoomChange, enabled}: Options) {
  const touches = useRef(new Map<number, Point>())
  const pinch = useRef<{distance: number; zoom: number; fraction: number} | null>(null)
  const pan = useRef<{x: number; scroll: number} | null>(null)
  const anchor = useRef<{fraction: number; clientX: number} | null>(null)
  const reset = () => {touches.current.clear(); pinch.current = null; pan.current = null; anchor.current = null}
  const applyAnchor = () => {
    const element = viewport.current, wave = track.current, pending = anchor.current
    if (!element || !wave || !pending) return
    const rect = wave.getBoundingClientRect()
    element.scrollLeft = Math.min(Math.max(0, element.scrollWidth - element.clientWidth),
      Math.max(0, element.scrollLeft + rect.left + pending.fraction * rect.width - pending.clientX))
    anchor.current = null
  }
  useLayoutEffect(applyAnchor, [zoom])
  useEffect(() => {
    window.addEventListener('blur', reset)
    return () => {window.removeEventListener('blur', reset); reset()}
  }, [])
  useEffect(() => {if (!enabled) reset()}, [enabled])
  const pair = () => [...touches.current.values()]
  const distance = (points: Point[]) => Math.hypot(points[1].x - points[0].x, points[1].y - points[0].y)

  const onPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    if (!enabled || !onZoomChange || event.pointerType !== 'touch' || touches.current.size >= 2
      || (event.target instanceof Element && event.target.closest('button'))) return
    touches.current.set(event.pointerId, {x: event.clientX, y: event.clientY})
    event.currentTarget.setPointerCapture?.(event.pointerId)
    if (touches.current.size === 1) pan.current = {x: event.clientX, scroll: event.currentTarget.scrollLeft}
    if (touches.current.size === 2) {
      const points = pair(), rect = track.current?.getBoundingClientRect(), separation = distance(points)
      if (rect && rect.width > 0 && separation > 0) {
        pinch.current = {distance: separation, zoom,
          fraction: Math.max(0, Math.min(1, ((points[0].x + points[1].x) / 2 - rect.left) / rect.width))}
      }
      pan.current = null
    }
  }
  const onPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    if (!enabled || !touches.current.has(event.pointerId)) return
    touches.current.set(event.pointerId, {x: event.clientX, y: event.clientY})
    if (touches.current.size === 2 && pinch.current && onZoomChange) {
      event.preventDefault()
      const points = pair(), initial = pinch.current
      const next = pinchZoom(initial.zoom, initial.distance, distance(points))
      anchor.current = {fraction: initial.fraction, clientX: (points[0].x + points[1].x) / 2}
      if (next === zoom) applyAnchor()
      else onZoomChange(next)
    } else if (touches.current.size === 1 && pan.current) {
      event.currentTarget.scrollLeft = Math.max(0, pan.current.scroll + pan.current.x - event.clientX)
    }
  }
  const onPointerEnd = (event: PointerEvent<HTMLDivElement>) => {
    if (!touches.current.delete(event.pointerId)) return
    pinch.current = null; pan.current = null; anchor.current = null
    if (event.currentTarget.hasPointerCapture?.(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId)
  }
  return {onPointerDown, onPointerMove, onPointerUp: onPointerEnd, onPointerCancel: onPointerEnd, onLostPointerCapture: onPointerEnd}
}
