import {describe,it,expect} from 'vitest'
import {fitRecordingMarkers,markerSelection,validateAudioMarkers} from './audioMarkers'
import {projectSnapshot,type StoredProject} from './projectRepository'
import type {EditorState} from '../types'

describe('source-relative audio markers',()=>{
  it('selects a valid full-length region near the end of a long source',()=>{
    expect(markerSelection({id:'end',time:118,label:'Chorus'},120,15)).toEqual([105,120])
    expect(markerSelection({id:'zero',time:0,label:'Start'},3,29)).toEqual([0,3])
  })
  it('rejects null, duplicate, nonfinite, out-of-range and oversized marker lists',()=>{
    const marker={id:'one',time:1,label:'Start'}
    for(const value of [null,[marker,marker],[{...marker,time:NaN}],[{...marker,time:-1}],[{...marker,time:4}],
      Array.from({length:65},(_,i)=>({...marker,id:String(i)}))])expect(()=>validateAudioMarkers(value as never,3)).toThrow()
    expect(validateAudioMarkers(undefined,3)).toEqual([])
  })
  it('fits only a small recorder/codec endpoint difference without changing valid positions',()=>{
    expect(fitRecordingMarkers([{id:'one',time:3.05,label:'End'}],3)[0].time).toBe(3)
    expect(()=>fitRecordingMarkers([{id:'one',time:4,label:'Invalid'}],3)).toThrow()
  })
  it('persists marker edits without dropping real media or invalidating existing audio output',()=>{
    const effects={volume:1,fadeIn:0,fadeOut:0,normalize:false},source={bytes:new Uint8Array([1,2,3]).buffer,type:'audio/wav'}
    const previous:StoredProject={id:'one',sourceDuration:3,effects,source,output:source,summary:{id:'one',name:'Tone',sourceName:'source.wav',duration:3,trimStart:0,trimEnd:3,updatedAt:'2026-11-03T00:00:00Z',status:'exported'}}
    const editor:EditorState={projectID:'one',projectName:'Tone',asset:{fileName:'source.wav',duration:3,peaks:[],buffer:null,isDemo:false},trimStart:0,trimEnd:3,effects,markers:[{id:'mark',time:1,label:'Start'}]}
    const saved=projectSnapshot(editor,previous)
    expect(saved.markers).toEqual(editor.markers)
    expect(saved.source).toBe(source);expect(saved.output).toBe(source);expect(saved.summary.status).toBe('exported')
    expect(previous.markers).toBeUndefined()
  })
})
