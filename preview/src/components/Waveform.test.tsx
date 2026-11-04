import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { Waveform } from './Waveform'
afterEach(() => { cleanup(); vi.restoreAllMocks(); vi.unstubAllGlobals() })

describe('Waveform editor', () => {
  it('disconnects the editable waveform resize observer when unmounted', () => {
    const observe = vi.fn(), disconnect = vi.fn()
    vi.stubGlobal('ResizeObserver', class {observe = observe; disconnect = disconnect; unobserve() {}})
    const {unmount} = render(<Waveform peaks={[0.2,0.7]} duration={20} start={0} end={1} editable />)
    expect(observe).toHaveBeenCalledWith(screen.getByTestId('waveform-track'))
    unmount()
    expect(disconnect).toHaveBeenCalledTimes(1)
  })
  it('does not emit duplicate edits when a focused handle is already at its limit', () => {
    const onChange = vi.fn()
    render(<Waveform peaks={[0.2,0.7]} duration={20} start={0} end={1} editable onChange={onChange} />)
    fireEvent.keyDown(screen.getByLabelText('Kesim başlangıcı'),{key:'ArrowLeft'})
    fireEvent.keyDown(screen.getByLabelText('Kesim bitişi'),{key:'ArrowLeft'})
    expect(onChange).not.toHaveBeenCalled()
  })
  it('keeps End-key edits valid at maximum length with a fractional start', () => {
    const onChange = vi.fn()
    render(<Waveform peaks={[0.2,0.7]} duration={60} start={3.2} end={12} editable onChange={onChange} />)
    fireEvent.keyDown(screen.getByLabelText('Kesim bitişi'),{key:'End'})
    const [start,end] = onChange.mock.calls[0]
    expect(start).toBe(3.2)
    expect(end-start).toBeLessThanOrEqual(29)
    expect(end-start).toBeCloseTo(29,10)
  })
  it('uses supplied localized accessible trim labels', () => {
    render(<Waveform peaks={[0.2,0.7]} duration={20} start={2} end={12} editable labels={{start:'Trim start',end:'Trim end'}} />)
    expect(screen.getByRole('slider',{name:'Trim start'})).toHaveAttribute('aria-valuenow','2')
    expect(screen.getByRole('slider',{name:'Trim end'})).toHaveAttribute('aria-valuenow','12')
  })
  it('exposes keyboard-accessible start and end controls', () => {
    const onChange = vi.fn()
    render(
      <Waveform
        peaks={[0.2, 0.7, 0.4, 0.9]}
        duration={20}
        start={2}
        end={12}
        editable
        onChange={onChange}
      />,
    )
    fireEvent.keyDown(screen.getByLabelText('Kesim başlangıcı'), { key:'ArrowRight' })
    expect(onChange).toHaveBeenCalledWith(2.1, 12)
    fireEvent.keyDown(screen.getByLabelText('Kesim bitişi'), { key:'ArrowLeft', shiftKey:true })
    expect(onChange).toHaveBeenCalledWith(2, 11)
  })

  it('keeps the entire waveform and time axis at 3× zoom', () => {
    const {container} = render(<Waveform peaks={[0.2,0.4,0.6,0.8]} duration={20} start={2} end={12} zoom={3} />)
    expect(container.querySelector('.waveform-track')).toHaveStyle({width:'300%'})
    expect(container.querySelectorAll('.waveform-bars i')).toHaveLength(4)
    expect(container.querySelector('.waveform-selection')).toHaveStyle({left:'10%',width:'50%'})
  })
  it('uses actual pointer coordinates after zoom and horizontal scrolling', () => {
    const onChange = vi.fn()
    render(<Waveform peaks={[0.2,0.7]} duration={20} start={2} end={12} zoom={3} editable onChange={onChange} />)
    vi.spyOn(screen.getByTestId('waveform-track'),'getBoundingClientRect').mockReturnValue({left:-200,width:1200} as DOMRect)
    const handle = screen.getByLabelText('Kesim başlangıcı')
    handle.setPointerCapture = vi.fn()
    fireEvent.pointerDown(handle,{clientX:250,pointerId:1})
    expect(onChange).toHaveBeenCalledWith(7.5,12)
  })
})
