import type { AudioEffects } from '../types'
import { encodePCMAsWav, renderSelection, type AudioSamples } from './audioProcessing'
import {calculatePeaksAsync} from './waveform'
import {validateImportSize,validateDecodedImport,validateWavImportHeader} from './mediaImportLimits'
import {abortable} from './audioConversion'
export {calculatePeaks} from './waveform'

let sharedContext: AudioContext | null = null
export function getAudioContext() {
  sharedContext ??= new AudioContext()
  return sharedContext
}

export async function decodeAudioFile(file: Blob,signal=new AbortController().signal) {
  validateImportSize(file.size)
  signal.throwIfAborted()
  const context=new AudioContext()
  try{
    validateWavImportHeader(await abortable(file.slice(0,44).arrayBuffer(),signal),context.sampleRate)
    const bytes = await abortable(file.arrayBuffer(),signal)
    const buffer = await abortable(context.decodeAudioData(bytes),signal)
    validateDecodedImport(buffer)
    return { buffer, duration: buffer.duration, peaks: await calculatePeaksAsync(buffer,240,signal) }
  }finally{await context.close()}
}

export function createDemoPeaks(count = 180) {
  return Array.from({ length: count }, (_, index) => Math.abs(Math.sin(index * 1.73)) * 0.7)
}

export function createDemoBuffer(duration = 24) {
  const context = getAudioContext()
  const buffer = context.createBuffer(1, Math.floor(context.sampleRate * duration), context.sampleRate)
  const channel = buffer.getChannelData(0)
  const notes = [261.63, 329.63, 392, 523.25, 392, 329.63]
  for (let index = 0; index < channel.length; index += 1) {
    const time = index / buffer.sampleRate
    const frequency = notes[Math.floor(time / 0.5) % notes.length]
    const phase = (time % 0.5) / 0.5
    const envelope = Math.min(1, phase * 8) * (1 - phase)
    channel[index] = (Math.sin(2 * Math.PI * frequency * time)
      + Math.sin(2 * Math.PI * frequency * 2 * time) * 0.22) * envelope * 0.34
  }
  return buffer
}

export function encodeSelectionAsWav(buffer: AudioSamples, start: number, end: number, effects: AudioEffects,bitDepth:16|24=16) {
  return encodePCMAsWav(renderSelection(buffer, start, end, effects),bitDepth)
}
