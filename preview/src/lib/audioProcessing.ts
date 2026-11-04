import type { AudioEffects } from '../types'
import {filterStudio,isNeutralStudio,limitPeaks,studioSettings,validateStudioRate} from './studioEffects'
import {crossfadeOwnedLoop,validateLoopCrossfade} from './loopCrossfade'

export interface AudioSamples {
  sampleRate: number
  length: number
  numberOfChannels: number
  getChannelData(channel: number): Float32Array
}
export interface ProcessedAudio {
  sourceOffset?: number
  sampleRate: number
  channels: Float32Array[]
  length: number
  duration: number
  appliedGain: number
}

// Preview and export share this deterministic PCM pipeline. Scan every sample
// and channel; reduce gain before rendering instead of hard-clipping the signal.
export function renderSelection(buffer: AudioSamples, start: number, end: number, effects: AudioEffects): ProcessedAudio {
  if(!Number.isInteger(buffer.numberOfChannels)||buffer.numberOfChannels<1||buffer.numberOfChannels>2)throw Error('Yalnız mono/stereo desteklenir / Only mono/stereo is supported')
  if (![start, end, buffer.sampleRate, effects.volume, effects.fadeIn, effects.fadeOut].every(Number.isFinite)
    || buffer.sampleRate <= 0 || start < 0 || end <= start || end > buffer.length / buffer.sampleRate + 1e-6
    || effects.volume < 0 || effects.fadeIn < 0 || effects.fadeOut < 0 || buffer.numberOfChannels < 1) {
    throw new Error('Invalid audio selection or effects')
  }
  const first = Math.round(start * buffer.sampleRate)
  const last = Math.min(buffer.length, Math.round(end * buffer.sampleRate))
  const length = last - first
  if (length < 1) throw new Error('Empty audio selection')
  const count = buffer.numberOfChannels
  const duration = length / buffer.sampleRate
  const fadeIn = Math.min(effects.fadeIn, duration / 2)
  const fadeOut = Math.min(effects.fadeOut, duration / 2)
  const studio=studioSettings(effects.studio)
  validateStudioRate(studio,buffer.sampleRate)
  // Preserve the legacy neutral path byte-for-byte. Only active new settings
  // allocate/filter a selected copy; never process the unselected entire source.
  let selected:Float32Array[]|undefined
  if(!isNeutralStudio(studio)){
    const copies=Array.from({length:count},(_,channel)=>buffer.getChannelData(channel).slice(first,last))
    if(copies.some(values=>values.length!==length||values.some(value=>!Number.isFinite(value))))throw Error('Invalid audio samples')
    selected=filterStudio(copies,buffer.sampleRate,studio)
  }
  const outputCount=selected?.length??count
  let peak = 0
  for (let channel = 0; channel < outputCount; channel += 1) {
    const values = selected?.[channel]??buffer.getChannelData(channel)
    for (let index = selected?0:first; index < (selected?length:last); index += 1) {
      if (!Number.isFinite(values[index])) throw new Error('Invalid audio samples')
      peak = Math.max(peak, Math.abs(values[index]))
    }
  }
  const normalizedGain = effects.normalize && peak > 0 ? 0.95 / peak : 1
  const requestedGain = effects.volume * normalizedGain
  const appliedGain = peak > 0 ? (studio.limiter?requestedGain:Math.min(requestedGain, 0.99 / peak)) : 0
  if(!Number.isFinite(appliedGain))throw Error('Invalid audio gain')
  const channels = Array.from({ length: outputCount }, (_, channel) => {
    const input = selected?.[channel]??buffer.getChannelData(channel)
    const output = new Float32Array(length)
    for (let frame = 0; frame < length; frame += 1) {
      const attack = fadeIn > 0 ? Math.min(1, frame / (fadeIn * buffer.sampleRate)) : 1
      const release = fadeOut > 0 ? Math.min(1, (length - 1 - frame) / (fadeOut * buffer.sampleRate)) : 1
      output[frame] = input[(selected?0:first) + frame] * appliedGain * Math.min(attack, release)
      if(!Number.isFinite(output[frame]))throw Error('Invalid processed audio')
    }
    return output
  })
  if(studio.limiter)limitPeaks(channels,buffer.sampleRate,studio.ceiling)
  const seconds=effects.loopCrossfade===undefined?0:effects.loopCrossfade
  validateLoopCrossfade(seconds)
  if(!seconds)return {sampleRate:buffer.sampleRate,channels,length,duration,appliedGain}
  const loop=crossfadeOwnedLoop(channels,buffer.sampleRate,seconds)
  return {sampleRate:buffer.sampleRate,channels:loop.channels,length:loop.length,duration:loop.length/buffer.sampleRate,appliedGain,
    ...(loop.sourceOffset?{sourceOffset:loop.sourceOffset}:{})}
}

export function encodePCMAsWav(audio: ProcessedAudio,bitDepth:16|24=16): Blob {
  const count = audio.channels.length
  if(![16,24].includes(bitDepth)||![1,2].includes(count)||!Number.isInteger(audio.length)||audio.length<1
    ||!Number.isInteger(audio.sampleRate)||audio.sampleRate<1||audio.sampleRate>192000
    ||audio.channels.some(channel=>channel.length!==audio.length))throw Error('Invalid PCM format')
  const bytesPerSample=bitDepth/8,byteCount=44+audio.length*count*bytesPerSample
  if(!Number.isSafeInteger(byteCount)||byteCount>256*1024*1024)throw Error('WAV exceeds memory limit')
  const bytes = new ArrayBuffer(byteCount)
  const view = new DataView(bytes)
  const text = (offset: number, value: string) => {
    for (let i = 0; i < value.length; i += 1) view.setUint8(offset + i, value.charCodeAt(i))
  }
  text(0, 'RIFF'); view.setUint32(4, bytes.byteLength - 8, true); text(8, 'WAVE'); text(12, 'fmt ')
  view.setUint32(16, 16, true); view.setUint16(20, 1, true); view.setUint16(22, count, true)
  view.setUint32(24, audio.sampleRate, true); view.setUint32(28, audio.sampleRate * count * bytesPerSample, true)
  view.setUint16(32, count * bytesPerSample, true); view.setUint16(34, bitDepth, true); text(36, 'data')
  view.setUint32(40, bytes.byteLength - 44, true)
  let offset = 44
  for (let frame = 0; frame < audio.length; frame += 1) {
    for (const channel of audio.channels) {
      const sample = channel[frame]
      if(!Number.isFinite(sample)||Math.abs(sample)>1)throw Error('Invalid or clipped PCM samples')
      if(bitDepth===16)view.setInt16(offset,Math.round(sample*(sample<0?32768:32767)),true)
      else{
        const value=Math.round(sample*(sample<0?8388608:8388607))
        view.setUint8(offset,value&255);view.setUint8(offset+1,(value>>8)&255);view.setUint8(offset+2,(value>>16)&255)
      }
      offset += bytesPerSample
    }
  }
  return new Blob([bytes], { type: 'audio/wav' })
}
