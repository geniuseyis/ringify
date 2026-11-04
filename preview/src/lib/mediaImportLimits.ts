import type {AudioSamples} from './audioProcessing'
export const importLimits={inputBytes:32*1024*1024,decodedBytes:48*1024*1024,duration:120}
export function validateImportSize(size:number){
  if(!Number.isSafeInteger(size)||size<=0||size>importLimits.inputBytes)throw Error('En fazla 32 MiB ses/video seçin. / Choose audio/video up to 32 MiB.')
}
export function validateDecodedImport(audio:AudioSamples){
  if(!Number.isInteger(audio.length)||audio.length<1||!Number.isFinite(audio.sampleRate)||audio.sampleRate<=0
    ||![1,2].includes(audio.numberOfChannels))throw Error('Geçerli mono/stereo ses gerekir. / Valid mono/stereo audio is required.')
  if(audio.length/audio.sampleRate<1||audio.length/audio.sampleRate>importLimits.duration)throw Error('Kaynak 1–120 saniye olmalı. / Source must be 1–120 seconds.')
  if(audio.length*audio.numberOfChannels*4>importLimits.decodedBytes)throw Error('Açılmış ses 48 MiB sınırını aşıyor. / Decoded audio exceeds 48 MiB.')
}
// Reject oversized canonical PCM WAV before its decoder allocates a full buffer.
// Compressed codec internals remain browser-owned; this is not a decoder sandbox guarantee.
export function validateWavImportHeader(header:ArrayBuffer,decodedRate:number){
  if(header.byteLength<44)return
  const v=new DataView(header)
  if(v.getUint32(0,false)!==0x52494646||v.getUint32(8,false)!==0x57415645||v.getUint32(12,false)!==0x666d7420
    ||v.getUint32(16,true)!==16||v.getUint32(36,false)!==0x64617461)return
  const rate=v.getUint32(24,true),channels=v.getUint16(22,true),alignment=v.getUint16(32,true),data=v.getUint32(40,true)
  if(!rate||!alignment)return
  const seconds=data/alignment/rate
  if(seconds>importLimits.duration||seconds*decodedRate*channels*4>importLimits.decodedBytes)throw Error('WAV süre/bellek sınırını aşıyor. / WAV exceeds duration/memory limits.')
}
