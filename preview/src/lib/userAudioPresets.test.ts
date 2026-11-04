import {describe,it,expect} from 'vitest'
import {applyUserPreset,validateUserPreset,type UserAudioPreset} from './userAudioPresets'
import {neutralStudio} from './studioEffects'

const preset=():UserAudioPreset=>({id:'voice',name:'Voice',createdAt:'2026-11-02T10:00:00Z',updatedAt:'2026-11-02T10:00:00Z',
  effects:{volume:.8,fadeIn:4,fadeOut:3,normalize:true,studio:{...neutralStudio,mid:2}}})
describe('personal audio preset safety',()=>{
  it('retains the loop parameter when validating and applying a saved personal preset',()=>{
    const saved=preset();saved.effects.loopCrossfade=.03
    expect(validateUserPreset(saved).effects.loopCrossfade).toBe(.03)
    expect(applyUserPreset(saved,1,48000).loopCrossfade).toBe(.03)
  })
  it('adapts fades to the actual selection without mutating the saved settings',()=>{
    const saved=preset(),before=structuredClone(saved),applied=applyUserPreset(saved,1,48000)
    expect(applied).toEqual({...saved.effects,fadeIn:.5,fadeOut:.5})
    expect(saved).toEqual(before)
  })
  it('rejects corrupt or partial data instead of replacing studio settings silently',()=>{
    for(const invalid of [null,{...preset(),name:' '},{...preset(),updatedAt:'invalid'},
      {...preset(),effects:{...preset().effects,volume:NaN}},
      {...preset(),effects:{...preset().effects,studio:null}},
      {...preset(),effects:{...preset().effects,studio:{mid:2}}}])expect(()=>validateUserPreset(invalid)).toThrow()
  })
  it('uses the actual Nyquist and rejects invalid source durations or rates',()=>{
    const saved=preset();saved.effects.studio={...neutralStudio,high:2}
    expect(()=>applyUserPreset(saved,2,8000)).toThrow()
    for(const [duration,rate]of [[NaN,48000],[.5,48000],[30,48000],[2,NaN]])expect(()=>applyUserPreset(saved,duration,rate)).toThrow()
  })
})
