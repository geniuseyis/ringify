import {afterEach,describe,it,expect,vi} from 'vitest'
import {cleanup,render,screen,fireEvent} from '@testing-library/react'
import {AudioMarkersPanel} from './AudioMarkersPanel'
import type {EditorState} from '../types'
afterEach(cleanup)
const editor=():EditorState=>({projectID:'one',projectName:'Tone',trimStart:0,trimEnd:15,
  asset:{fileName:'source.wav',duration:120,peaks:[],buffer:null,isDemo:false},effects:{volume:1,fadeIn:0,fadeOut:0,normalize:false},
  markers:[{id:'chorus',time:118,label:'Chorus'}]})
describe('source marker controls',()=>{
  it('selects the source-relative region containing a bookmark',()=>{
    const onSelect=vi.fn()
    render(<AudioMarkersPanel editor={editor()} language="en" time={0} onChange={vi.fn()} onSelect={onSelect}/>)
    fireEvent.click(screen.getByText('Markers · 1'))
    fireEvent.click(screen.getByRole('button',{name:/^Chorus · [0-9]/}))
    expect(onSelect).toHaveBeenCalledWith(105,120)
  })
  it('adds an actual playhead position without changing effects or selection',()=>{
    const original=editor(),onChange=vi.fn()
    render(<AudioMarkersPanel editor={original} language="en" time={4.25} onChange={onChange} onSelect={vi.fn()}/>)
    fireEvent.click(screen.getByText('Markers · 1'))
    fireEvent.change(screen.getByLabelText('Marker label (optional)'),{target:{value:'Intro'}})
    fireEvent.click(screen.getByRole('button',{name:/Mark This Position/}))
    const changed=onChange.mock.calls[0][0] as EditorState
    expect(changed.markers).toContainEqual(expect.objectContaining({time:4.25,label:'Intro'}))
    expect(changed.effects).toEqual(original.effects);expect(changed.trimEnd).toBe(original.trimEnd)
  })
  it('requires confirmation before deleting marker metadata',()=>{
    const onChange=vi.fn()
    render(<AudioMarkersPanel editor={editor()} language="en" time={0} onChange={onChange} onSelect={vi.fn()}/>)
    fireEvent.click(screen.getByText('Markers · 1'))
    fireEvent.click(screen.getByRole('button',{name:'Chorus · Delete'}))
    fireEvent.click(screen.getByRole('button',{name:'Cancel'}))
    expect(onChange).not.toHaveBeenCalled()
  })
})
