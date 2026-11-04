import {freeProjectLimit,proProjectLimit} from './proOffering'
import type {AudioEffects,Language} from '../types'
import {isNeutralStudio,studioSettings} from './studioEffects'

export function canCreateProject(count:number,hasVerifiedPro:boolean){
  return Number.isSafeInteger(count)&&count>=0&&count<(hasVerifiedPro?proProjectLimit:freeProjectLimit)
}
export function canChangeNormalization(current:boolean,next:boolean,hasVerifiedPro:boolean){
  return !next||current||hasVerifiedPro
}
export function canChangeStudioEffects(current:Pick<AudioEffects,'studio'>,next:Pick<AudioEffects,'studio'>,hasVerifiedPro:boolean){
  try{return isNeutralStudio(next.studio)||hasVerifiedPro||JSON.stringify(studioSettings(current.studio))===JSON.stringify(studioSettings(next.studio))}
  catch{return false}
}
export class AdvancedAudioAccessError extends Error {
  constructor(language:Language='tr'){super(language==='tr'?'Yeni gelişmiş efekt ayarları için Ringify Pro gerekir.':'Ringify Pro is required to enable new advanced effects.');this.name='AdvancedAudioAccessError'}
}
export class HighPrecisionAccessError extends Error {
  constructor(language:Language='tr'){super(language==='tr'?'Yeni PCM 24-bit dışa aktarımı için Ringify Pro gerekir.':'Ringify Pro is required for new PCM 24-bit exports.');this.name='HighPrecisionAccessError'}
}
export class LibraryAccessError extends Error {
  constructor(language:Language='tr'){super(language==='tr'?'Yeni favori ve koleksiyon düzenlemeleri için Ringify Pro gerekir.':'Ringify Pro is required for new favorites and collection assignments.');this.name='LibraryAccessError'}
}
export class ProjectLimitError extends Error {
  constructor(language:Language='tr',hasVerifiedPro=false){
    super(hasVerifiedPro
      ?(language==='tr'?`Pro planda ${proProjectLimit} proje sınırına ulaştın. Yeni proje için ek proje yuvası gerekir. Mevcut projeler korunur.`:`You have reached the Pro plan's ${proProjectLimit}-project limit. An extra project slot is required for a new project. Existing projects are preserved.`)
      :(language==='tr'?`Normal planda ${freeProjectLimit} proje saklayabilirsin. Mevcut projelerini kullanabilir veya Pro planlarını inceleyebilirsin.`:`The Normal plan stores ${freeProjectLimit} projects. You can keep using existing projects or view Pro plans.`))
    this.name='ProjectLimitError'
  }
}
export class ProFeatureError extends Error {
  constructor(language:Language='tr'){
    super(language==='tr'?'Yeni normalize işlemi için Ringify Pro gerekir.':'Ringify Pro is required to enable normalization.')
    this.name='ProFeatureError'
  }
}
