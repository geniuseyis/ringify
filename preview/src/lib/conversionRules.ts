import type {AudioSamples} from './audioProcessing'

export const conversionLimits={inputBytes:32*1024*1024,decodedBytes:48*1024*1024,duration:120} as const
export type ConversionStage='reading'|'decoding'|'encoding'|'verifying'
export class ConversionError extends Error {
  constructor(readonly code:'type'|'size'|'duration'|'channels'|'codec'|'memory'|'samples'|'verification'){super(code)}
}
export function validateConversionSource(name:string,size:number,header:Uint8Array):'mp3'|'mp4'{
  if(!Number.isFinite(size)||size<=0||size>conversionLimits.inputBytes)throw new ConversionError('size')
  const ext=name.split('.').pop()?.toLowerCase()
  const id3=header[0]===0x49&&header[1]===0x44&&header[2]===0x33
  const frame=header[0]===0xff&&(header[1]&0xe0)===0xe0&&(header[1]&0x18)!==8&&(header[1]&6)!==0
  const mp4=header.length>=12&&String.fromCharCode(...header.slice(4,8))==='ftyp'
  if(ext==='mp3'&&(id3||frame))return 'mp3'
  if(ext==='mp4'&&mp4)return 'mp4'
  throw new ConversionError('type')
}
export function validateConversionAudio(audio:AudioSamples){
  if(!Number.isInteger(audio.length)||audio.length<1||!Number.isFinite(audio.sampleRate)||audio.sampleRate<8000||audio.sampleRate>96000)throw new ConversionError('samples')
  if(!Number.isInteger(audio.numberOfChannels)||audio.numberOfChannels<1||audio.numberOfChannels>2)throw new ConversionError('channels')
  const duration=audio.length/audio.sampleRate
  if(duration>conversionLimits.duration)throw new ConversionError('duration')
  if(audio.length*audio.numberOfChannels*4>conversionLimits.decodedBytes)throw new ConversionError('memory')
  return duration
}
export function verifyConversionWav(bytes:ArrayBuffer,audio:Pick<AudioSamples,'length'|'sampleRate'|'numberOfChannels'>){
  const expected=44+audio.length*audio.numberOfChannels*2
  if(bytes.byteLength!==expected)throw new ConversionError('verification')
  const view=new DataView(bytes),text=(offset:number,count:number)=>String.fromCharCode(...new Uint8Array(bytes,offset,count))
  if(text(0,4)!=='RIFF'||text(8,8)!=='WAVEfmt '||text(36,4)!=='data'||view.getUint32(4,true)!==expected-8||view.getUint32(16,true)!==16||view.getUint16(20,true)!==1||view.getUint16(22,true)!==audio.numberOfChannels||view.getUint32(24,true)!==audio.sampleRate||view.getUint32(28,true)!==audio.sampleRate*audio.numberOfChannels*2||view.getUint16(32,true)!==audio.numberOfChannels*2||view.getUint16(34,true)!==16||view.getUint32(40,true)!==expected-44)throw new ConversionError('verification')
}
