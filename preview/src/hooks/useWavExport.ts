import {useEffect,useRef,useState} from 'react'
import type {EditorState,Language} from '../types'
import {renderSelectionExport} from '../lib/selectionExport'
import {selectionExportPlan,verifySelectionWav,type WavBitDepth,type WavWorkStage} from '../lib/wavExportPlan'
import {sanitizeFileName} from '../lib/format'

type ExportStatus='idle'|'preparing'|'saving'|'success'|'error'
export interface WavExportResult {url:string;blob:Blob;fileName:string;duration:number;bitDepth:WavBitDepth;sampleRate:number;channels:number}

export function useWavExport(editor:EditorState,onComplete:(name:string,blob:Blob)=>Promise<void>,language:Language,bitDepth:WavBitDepth=16){
  const [status,setStatus]=useState<ExportStatus>('idle')
  const [error,setError]=useState<string|null>(null)
  const [result,setResult]=useState<WavExportResult|null>(null)
  const [stage,setStage]=useState<WavWorkStage>('processing')
  const controller=useRef<AbortController|null>(null)
  const phase=useRef<ExportStatus>('idle'),generation=useRef(0),mounted=useRef(true),url=useRef<string|null>(null)
  const {buffer}=editor.asset
  const identity=JSON.stringify([editor.projectID,editor.projectName,editor.trimStart,editor.trimEnd,editor.effects,bitDepth])
  function transition(next:ExportStatus){phase.current=next;setStatus(next)}
  function releaseUrl(){if(url.current)URL.revokeObjectURL(url.current);url.current=null}
  useEffect(()=>{
    mounted.current=true;generation.current+=1;controller.current?.abort();controller.current=null;releaseUrl();setResult(null);setError(null);transition('idle')
    return()=>{mounted.current=false;generation.current+=1;controller.current?.abort();controller.current=null;releaseUrl()}
  },[buffer,identity])

  async function start(fileName:string){
    if(!mounted.current||!['idle','error'].includes(phase.current))return
    const token=++generation.current,isCurrent=()=>mounted.current&&token===generation.current
    const cleanName=sanitizeFileName(fileName)
    if(!cleanName||!buffer){setError(language==='tr'?'Geçerli bir dosya adı ve gerçek ses verisi gerekiyor.':'A valid file name and actual audio are required.');transition('error');return}
    const snapshot={start:editor.trimStart,end:editor.trimEnd,effects:{...editor.effects}}
    const abort=new AbortController();controller.current=abort
    setError(null);setResult(null);setStage('processing');releaseUrl();transition('preparing')
    try{
      const plan=selectionExportPlan(buffer,snapshot.start,snapshot.end,snapshot.effects,bitDepth)
      const blob=await renderSelectionExport(buffer,snapshot.start,snapshot.end,snapshot.effects,bitDepth,abort.signal,next=>{if(isCurrent()&&phase.current==='preparing')setStage(next)})
      if(!isCurrent())return
      setStage('verifying')
      if(blob.size!==plan.byteCount)throw Error(language==='tr'?'WAV dosyası doğrulanamadı.':'The WAV file could not be verified.')
      const bytes=await blob.arrayBuffer()
      if(!isCurrent())return
      try{verifySelectionWav(bytes,plan)}catch{throw Error(language==='tr'?'WAV dosyası doğrulanamadı.':'The WAV file could not be verified.')}
      controller.current=null
      transition('saving') // Persistence commit is not cancellable; never imply rollback here.
      await onComplete(cleanName,blob)
      if(!isCurrent())return
      url.current=URL.createObjectURL(blob)
      setResult({url:url.current,blob,fileName:`${cleanName}.wav`,duration:plan.duration,bitDepth,sampleRate:plan.sampleRate,channels:plan.channels})
      transition('success')
    }catch(failure){if(isCurrent()){setError(failure instanceof Error?failure.message:(language==='tr'?'Dışa aktarma tamamlanamadı. Tekrar dene.':'Export failed. Try again.'));transition('error')}}
    finally{if(controller.current===abort){abort.abort();controller.current=null}}
  }
  function cancel(){if(phase.current!=='preparing')return;generation.current+=1;controller.current?.abort();controller.current=null;setError(null);transition('idle')}
  return {status,error,result,start,cancel,stage}
}
