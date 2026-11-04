import {useEffect,useRef,useState} from 'react'
import {convertToWav,type ConversionStage} from '../lib/audioConversion'

export function useAudioConversion(){
  const [stage,setStage]=useState<ConversionStage|'idle'|'success'|'error'>('idle')
  const [error,setError]=useState<unknown>(null)
  const [result,setResult]=useState<(Awaited<ReturnType<typeof convertToWav>>&{url:string})|null>(null)
  const active=useRef<AbortController|null>(null),url=useRef<string|null>(null),generation=useRef(0)
  function reset(){generation.current++;active.current?.abort();active.current=null;if(url.current)URL.revokeObjectURL(url.current);url.current=null;setResult(null);setError(null);setStage('idle')}
  useEffect(()=>()=>{generation.current++;active.current?.abort();if(url.current)URL.revokeObjectURL(url.current)},[])
  async function start(file:File){
    if(active.current)return
    reset();const token=generation.current,controller=new AbortController();active.current=controller
    try{
      const output=await convertToWav(file,controller.signal,next=>{if(token===generation.current)setStage(next)})
      if(token!==generation.current||controller.signal.aborted)return
      url.current=URL.createObjectURL(output.blob);setResult({...output,url:url.current});setStage('success')
    }catch(failure){if(token===generation.current&&!controller.signal.aborted){setError(failure);setStage('error')}}
    finally{if(token===generation.current)active.current=null}
  }
  return {stage,error,result,start,reset,busy:!['idle','success','error'].includes(stage)}
}
