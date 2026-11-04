import { describe, expect, it } from 'vitest'
import { SegmentPlayer } from './segmentPlayer'
import { FakeAudioContext, audioFixture } from '../test/audioFixtures'
const effects = {volume:1,fadeIn:0.1,fadeOut:0.1,normalize:false}
function player() {
  const context = new FakeAudioContext()
  const instance = new SegmentPlayer(context as unknown as AudioContext,
    audioFixture([Array<number>(1000).fill(0.4)]),2,7,effects)
  return {context,instance}
}
describe('selection playback clock', () => {
  it('pauses and resumes from the same sample position', async () => {
    const {context,instance} = player()
    await instance.play(); context.currentTime = 1.25; instance.pause()
    expect(instance.position).toBe(1.25)
    context.currentTime = 10; await instance.play()
    expect(context.sources[1].starts).toEqual([1.25])
    context.currentTime = 10.5
    expect(instance.position).toBe(1.75)
    instance.stop(); expect(instance.position).toBe(0)
  })
  it('loops only the rendered selection and wraps its clock', async () => {
    const {context,instance} = player()
    instance.setLoop(true); await instance.play()
    expect(context.sources[0].loop).toBe(true)
    expect(context.sources[0].buffer!.length).toBe(500)
    expect(context.sources[0].loopEnd).toBe(5)
    context.currentTime = 12.25
    expect(instance.position).toBe(2.25)
    instance.setLoop(false)
    expect(context.sources[0].loop).toBe(false)
  })
  it('ignores a delayed resume when stopped before permission resumes', async () => {
    const {context,instance} = player()
    let resume: () => void = () => undefined
    context.resume = () => new Promise<void>((resolve) => {resume=resolve})
    const pending = instance.play(); instance.stop(); resume(); await pending
    expect(context.sources).toHaveLength(0)
    expect(instance.isPlaying).toBe(false)
  })
})
