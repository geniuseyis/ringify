import {useEffect,useRef,type ReactNode} from 'react'
import {ChevronLeft} from 'lucide-react'
import type {Language} from '../types'

export function DetailHeader({title,language,onBack,trailing}:{title:string;language:Language;onBack:()=>void;trailing?:ReactNode}){
  const heading=useRef<HTMLHeadingElement>(null)
  useEffect(()=>{heading.current?.focus()},[title])
  return <header className="uf-detail-nav">
    <button type="button" onClick={onBack} aria-label={language==='tr'?'Geri':'Back'}><ChevronLeft size={23} aria-hidden="true"/></button>
    <h1 ref={heading} tabIndex={-1}>{title}</h1><span>{trailing}</span>
  </header>
}
