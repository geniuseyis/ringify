import {useState} from 'react'
import {cleanup, fireEvent, render, screen} from '@testing-library/react'
import {afterEach, describe, expect, it, vi} from 'vitest'
import {Waveform} from './Waveform'

afterEach(() => {cleanup(); vi.restoreAllMocks()})
function pointer(element: Element, type: string, id: number, x: number) {
  const event = new Event(type, {bubbles: true, cancelable: true})
  Object.assign(event, {pointerType: 'touch', pointerId: id, clientX: x, clientY: 100})
  fireEvent(element, event)
}
function setup(editable = true) {
  const onChange = vi.fn(), zoomChanged = vi.fn()
  function Harness() {
    const [zoom, setZoom] = useState(1)
    return <Waveform peaks={[0.2, 0.8]} duration={20} start={2} end={12} editable={editable} zoom={zoom}
      onChange={onChange} onZoomChange={next => {zoomChanged(next); setZoom(next)}}/>
  }
  const {container} = render(<Harness/>), viewport = container.querySelector('.waveform-viewport') as HTMLDivElement
  const track = screen.getByTestId('waveform-track'), outer = container.querySelector('.waveform-track') as HTMLDivElement
  Object.defineProperty(viewport, 'clientWidth', {value: 300})
  Object.defineProperty(viewport, 'scrollWidth', {get: () => 300 * parseFloat(outer.style.width) / 100})
  vi.spyOn(track, 'getBoundingClientRect').mockImplementation(() => ({left: -viewport.scrollLeft,
    width: 300 * parseFloat(outer.style.width) / 100}) as DOMRect)
  return {viewport, track, outer, onChange, zoomChanged}
}
describe('real waveform pinch interaction', () => {
  it('keeps the source anchor under two fingers while leaving trim settings unchanged', () => {
    const {viewport, outer, onChange, zoomChanged} = setup()
    pointer(viewport, 'pointerdown', 1, 75); pointer(viewport, 'pointerdown', 2, 225)
    pointer(viewport, 'pointermove', 2, 450)
    expect(zoomChanged).toHaveBeenLastCalledWith(2.5)
    expect(outer.style.width).toBe('250%')
    expect(viewport.scrollLeft).toBeCloseTo(112.5)
    expect(onChange).not.toHaveBeenCalled()
  })
  it('clears a cancelled gesture and starts the next gesture from the current zoom', () => {
    const {viewport, zoomChanged} = setup()
    pointer(viewport, 'pointerdown', 1, 100); pointer(viewport, 'pointerdown', 2, 200)
    pointer(viewport, 'pointermove', 2, 700)
    expect(zoomChanged).toHaveBeenLastCalledWith(3)
    pointer(viewport, 'pointercancel', 2, 700)
    pointer(viewport, 'pointermove', 1, 10)
    expect(zoomChanged).toHaveBeenCalledTimes(1)
    pointer(viewport, 'pointerdown', 3, 300); pointer(viewport, 'pointermove', 3, 200)
    expect(zoomChanged.mock.lastCall?.[0]).toBeCloseTo(3 * 190 / 290)
  })
  it('retains one-finger horizontal panning after zoom', () => {
    const {viewport} = setup()
    pointer(viewport, 'pointerdown', 1, 100); pointer(viewport, 'pointerdown', 2, 200)
    pointer(viewport, 'pointermove', 2, 700)
    pointer(viewport, 'pointerup', 1, 100); pointer(viewport, 'pointerup', 2, 700)
    const before = viewport.scrollLeft
    pointer(viewport, 'pointerdown', 3, 200); pointer(viewport, 'pointermove', 3, 150)
    expect(viewport.scrollLeft).toBeCloseTo(before + 50)
  })
  it('keeps ordinary browser gestures on read-only waveforms', () => {
    const {viewport, zoomChanged} = setup(false)
    pointer(viewport, 'pointerdown', 1, 100); pointer(viewport, 'pointerdown', 2, 200)
    pointer(viewport, 'pointermove', 2, 700)
    expect(zoomChanged).not.toHaveBeenCalled()
    expect(viewport.style.touchAction).toBe('')
  })
})
