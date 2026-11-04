import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { Waveform } from './Waveform'
afterEach(() => { cleanup(); vi.restoreAllMocks() })

describe('Waveform editor', () => {
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
