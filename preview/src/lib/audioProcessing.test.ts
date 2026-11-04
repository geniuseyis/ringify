import { describe, expect, it } from 'vitest'
import { renderSelection, encodePCMAsWav } from './audioProcessing'
import { audioFixture } from '../test/audioFixtures'
import { calculatePeaks } from './audio'

const neutral = {volume:1,fadeIn:0,fadeOut:0,normalize:false}
describe('shared playback/export PCM', () => {
  it('trims at sample coordinates without changing the source', () => {
    const input = audioFixture([[0,0.1,0.2,0.3,0.4,0.5]], 2)
    const result = renderSelection(input, 0.5, 2, neutral)
    expect([...result.channels[0]]).toEqual([...input.getChannelData(0).slice(1,4)])
    expect(result.duration).toBe(1.5)
    expect(input.getChannelData(0)[5]).toBe(0.5)
  })
  it.each([false,true])('prevents clipping with volume boost and normalize=%s, including missed narrow stereo peaks', (normalize) => {
    const left = Array<number>(100).fill(0.01)
    const right = Array<number>(100).fill(-0.1)
    right[3] = 0.9; left[17] = -0.8
    const result = renderSelection(audioFixture([left,right]),0,1,{...neutral,normalize,volume:1.5})
    for (const values of result.channels) for (const sample of values) expect(Math.abs(sample)).toBeLessThanOrEqual(0.990001)
    expect(result.channels[1][3] / result.channels[0][17]).toBeCloseTo(-0.9 / 0.8,5)
  })
  it('normalizes every channel to the same gain, leaving silence finite', () => {
    const signal = renderSelection(audioFixture([[0.1,-0.2],[0.4,0.2]],2),0,1,{...neutral,normalize:true})
    expect(signal.channels[1][0]).toBeCloseTo(0.95)
    expect(signal.channels[0][1]).toBeCloseTo(-0.475)
    expect([...renderSelection(audioFixture([[0,0]],2),0,1,{...neutral,normalize:true}).channels[0]]).toEqual([0,0])
  })
  it('mutes exactly, including fades and normalization', () => {
    const result = renderSelection(audioFixture([[0.7,-0.6]],2),0,1,{volume:0,fadeIn:0.3,fadeOut:0.3,normalize:true})
    expect(result.channels[0].every((sample) => sample === 0)).toBe(true)
  })
  it('uses the same linear fades and channel samples for WAV and preview', async () => {
    const pcm = renderSelection(audioFixture([Array<number>(100).fill(0.5),Array<number>(100).fill(-0.3)]),0,1,
      {...neutral,fadeIn:0.2,fadeOut:0.2})
    expect(pcm.channels[0][0]).toBe(0)
    expect(pcm.channels[0][10]).toBeCloseTo(0.25)
    expect(pcm.channels[0][99]).toBe(0)
    const view = new DataView(await encodePCMAsWav(pcm).arrayBuffer())
    for (let i=0;i<100;i++) for(let channel=0;channel<2;channel++) {
      const value = view.getInt16(44+(i*2+channel)*2,true)
      expect(Math.abs(value/(value<0?32768:32767)-pcm.channels[channel][i])).toBeLessThan(1/32767)
    }
  })
  it.each([[NaN,1],[0,Infinity],[-1,1],[1,1],[0,4]])('rejects invalid trim %s–%s', (start,end) => {
    expect(() => renderSelection(audioFixture([[0,1]],2),start,end,neutral)).toThrow()
  })
  it('waveform includes the right channel and true silence', () => {
    expect(calculatePeaks(audioFixture([[0,0],[0,0.8]],2),2)[1]).toBeCloseTo(0.8)
    expect(calculatePeaks(audioFixture([[0,0]],2),2)).toEqual([0,0])
  })
})
