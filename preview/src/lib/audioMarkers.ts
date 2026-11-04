import type {AudioMarker} from '../types'

export const maximumAudioMarkers=64
export function validateAudioMarkers(value:AudioMarker[]|undefined,duration:number):AudioMarker[]{
  const markers=value===undefined?[]:value
  if(!Number.isFinite(duration)||duration<=0||duration>1800||!Array.isArray(markers)||markers.length>maximumAudioMarkers)throw Error('Invalid source markers')
  const ids=new Set<string>()
  const result=markers.map(marker=>{
    if(!marker||typeof marker.id!=='string'||!marker.id||marker.id.length>128||ids.has(marker.id)
      ||!Number.isFinite(marker.time)||marker.time<0||marker.time>duration||typeof marker.label!=='string'
      ||!marker.label.trim()||marker.label!==marker.label.trim()||Array.from(marker.label).length>60||/[\u0000-\u001f\u007f-\u009f]/u.test(marker.label))throw Error('Invalid audio marker')
    ids.add(marker.id);return {id:marker.id,time:marker.time,label:marker.label}
  })
  return result.sort((a,b)=>a.time-b.time||a.id.localeCompare(b.id))
}
export function fitRecordingMarkers(markers:AudioMarker[]|undefined,duration:number):AudioMarker[]{
  if(markers!==undefined&&(!Array.isArray(markers)||markers.some(marker=>!Number.isFinite(marker.time)||marker.time>duration+.1)))throw Error('Recording marker exceeds source')
  return validateAudioMarkers(markers?.map(marker=>({...marker,time:Math.min(marker.time,duration)})),duration)
}
export function markerSelection(marker:AudioMarker,sourceDuration:number,preferredDuration:number):[number,number]{
  validateAudioMarkers([marker],sourceDuration)
  if(sourceDuration<1||!Number.isFinite(preferredDuration)||preferredDuration<1||preferredDuration>29)throw Error('Invalid selection duration')
  const duration=Math.min(preferredDuration,sourceDuration),start=Math.min(marker.time,sourceDuration-duration)
  return [start,start+duration]
}
