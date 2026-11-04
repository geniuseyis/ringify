import {useEffect,useId,useLayoutEffect,useRef,useState,type ReactNode} from 'react'
import {createPortal} from 'react-dom'
import {X} from 'lucide-react'

export function ModalSheet({title,closeLabel,onClose,busy=false,focusKey='',restoreFocusTo,children}: {
  title:string;closeLabel:string;onClose:()=>void;busy?:boolean;focusKey?:string;restoreFocusTo?:HTMLElement|null;children:ReactNode
}){
  const sheet=useRef<HTMLElement>(null),anchor=useRef<HTMLSpanElement>(null),titleId=useId(),latest=useRef({busy,onClose})
  const [portal,setPortal]=useState<HTMLElement|null>(null)
  const trigger=useRef(restoreFocusTo??document.activeElement as HTMLElement|null)
  latest.current={busy,onClose}
  useLayoutEffect(()=>{
    const source=anchor.current?.parentElement,app=source?.closest<HTMLElement>('.ringify-app')
    if(!source||!app)return
    // Escape screen-sized stacking/scroll containers while retaining their scoped
    // theme selectors and tokens. display:contents adds no second screen box.
    const host=document.createElement('div'),classes=new Set<string>()
    for(let owner:HTMLElement|null=source;owner&&owner!==app;owner=owner.parentElement){
      owner.classList.forEach(value=>classes.add(value))
    }
    host.className=Array.from(classes).join(' ')
    host.style.display='contents'
    const tokens=getComputedStyle(source)
    for(const property of Array.from(tokens)){
      if(property.startsWith('--'))host.style.setProperty(property,tokens.getPropertyValue(property))
    }
    host.dataset.modalHost=''
    app.append(host)
    setPortal(host)
    return()=>host.remove()
  },[])
  useEffect(()=>{
    const focusable=()=>Array.from(sheet.current?.querySelectorAll<HTMLElement>('button:not(:disabled),input:not(:disabled),select:not(:disabled),textarea:not(:disabled),a[href],[tabindex]:not([tabindex="-1"])')??[]).filter(el=>!el.hidden)
    function keydown(event:KeyboardEvent){
      if(event.key==='Escape'){event.preventDefault();event.stopPropagation();if(!latest.current.busy)latest.current.onClose();return}
      if(event.key!=='Tab')return
      const targets=focusable(),first=targets[0],last=targets[targets.length-1]
      if(!first){event.preventDefault();sheet.current?.focus();return}
      if(!sheet.current?.contains(document.activeElement)||(event.shiftKey&&document.activeElement===first)){event.preventDefault();(event.shiftKey?last:first).focus()}
      else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus()}
    }
    document.addEventListener('keydown',keydown,true)
    return()=>{document.removeEventListener('keydown',keydown,true);if(trigger.current?.isConnected)trigger.current.focus()}
  },[])
  useLayoutEffect(()=>{
    const target=sheet.current?.querySelector<HTMLElement>('[data-autofocus]:not(:disabled)')
      ??sheet.current?.querySelector<HTMLElement>('input:not(:disabled)')
      ??sheet.current?.querySelector<HTMLElement>('button:not(:disabled)')
    ;(target??sheet.current)?.focus()
  },[focusKey,portal])
  useLayoutEffect(()=>{
    const app=portal?.parentElement
    if(!app)return
    // The entire application, including its tab bar, is unavailable to pointer,
    // keyboard and assistive technology until the modal has been dismissed.
    const background=Array.from(app.children).filter((element):element is HTMLElement=>element instanceof HTMLElement&&element!==portal)
      .map(element=>({element,inert:element.getAttribute('inert'),hidden:element.getAttribute('aria-hidden')}))
    for(const {element} of background){element.setAttribute('inert','');element.setAttribute('aria-hidden','true')}
    return()=>{
      for(const {element,inert,hidden} of background){
        if(inert===null)element.removeAttribute('inert');else element.setAttribute('inert',inert)
        if(hidden===null)element.removeAttribute('aria-hidden');else element.setAttribute('aria-hidden',hidden)
      }
    }
  },[portal])
  const content=<div className="sheet-backdrop m5-sheet-backdrop" style={portal?{position:'absolute',inset:0,zIndex:60}:undefined} role="presentation" onMouseDown={event=>{if(event.target===event.currentTarget&&!busy)onClose()}}>
    <section ref={sheet} className="bottom-sheet m5-sheet" role="dialog" aria-modal="true" aria-labelledby={titleId} aria-busy={busy} tabIndex={-1}>
      <div className="sheet-grabber" aria-hidden="true" /><header><h2 id={titleId}>{title}</h2><button type="button" className="m5-icon" aria-label={closeLabel} disabled={busy} onClick={onClose}><X size={21} aria-hidden="true" /></button></header>{children}
    </section>
  </div>
  return <><span ref={anchor} hidden aria-hidden="true" />{portal?createPortal(content,portal):content}</>
}
