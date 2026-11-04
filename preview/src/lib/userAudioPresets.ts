import type {AudioEffects} from '../types'
import {studioSettings,validateStudioRate} from './studioEffects'
import {validateLoopCrossfade} from './loopCrossfade'

export interface UserAudioPreset {id:string;name:string;effects:AudioEffects;createdAt:string;updatedAt:string}
export const maximumUserPresets=64
export function validateUserPreset(value:unknown):UserAudioPreset {
  if(!value||typeof value!=='object')throw Error('Invalid preset')
  const preset=value as UserAudioPreset,fx=preset.effects
  if(typeof preset.id!=='string'||!preset.id||preset.id.length>128||typeof preset.name!=='string'
    ||preset.name!==preset.name.trim()||!preset.name||Array.from(preset.name).length>60||/[\u0000-\u001f\u007f-\u009f]/u.test(preset.name)
    ||typeof preset.createdAt!=='string'||!Number.isFinite(Date.parse(preset.createdAt))
    ||typeof preset.updatedAt!=='string'||!Number.isFinite(Date.parse(preset.updatedAt))
    ||!fx||typeof fx!=='object'||![fx.volume,fx.fadeIn,fx.fadeOut].every(x=>Number.isFinite(x)&&x>=0)
    ||fx.volume>1.5||fx.fadeIn>5||fx.fadeOut>5||typeof fx.normalize!=='boolean')throw Error('Invalid preset settings')
  if(fx.studio!==undefined&&(!fx.studio||typeof fx.studio!=='object'||
    !['low','mid','high','highPass','lowPass','channels','limiter','ceiling'].every(key=>Object.hasOwn(fx.studio!,key))))throw Error('Incomplete studio settings')
  validateLoopCrossfade(fx.loopCrossfade===undefined?0:fx.loopCrossfade)
  const effects:AudioEffects={volume:fx.volume,fadeIn:fx.fadeIn,fadeOut:fx.fadeOut,normalize:fx.normalize,
    ...(fx.loopCrossfade===undefined?{}:{loopCrossfade:fx.loopCrossfade}),
    ...(fx.studio===undefined?{}:{studio:studioSettings(fx.studio)})}
  return {id:preset.id,name:preset.name,effects,createdAt:preset.createdAt,updatedAt:preset.updatedAt}
}
export function applyUserPreset(preset:UserAudioPreset,duration:number,sampleRate:number):AudioEffects {
  const {effects}=validateUserPreset(preset)
  if(!Number.isFinite(duration)||duration<1||duration>29||!Number.isFinite(sampleRate)||sampleRate<8000||sampleRate>192000)throw Error('Invalid source')
  validateStudioRate(studioSettings(effects.studio),sampleRate)
  const maximum=Math.min(5,duration/2)
  return {...effects,fadeIn:Math.min(effects.fadeIn,maximum),fadeOut:Math.min(effects.fadeOut,maximum)}
}
