import {useEffect, useRef, useState} from 'react'
import {AudioLines, Bell, ChevronLeft, FileAudio, FileCheck2, Film, Mic, Scissors} from 'lucide-react'
import type {Language} from '../types'
import {LogoMark} from '../components/LogoMark'
import {PrimaryActionButton} from '../designSystem/StudioComponents'
import {designVariables} from '../designSystem/tokens'
import '../designSystem/welcome.css'

export function SplashScreen({language='tr'}:{language?:Language}) {
  return <section className="splash-screen v2-screen v3-screen v3-splash" style={designVariables}
    aria-label={language==='tr'?'Ringify açılış ekranı':'Ringify launch screen'}>
    <LogoMark size={72} />
    <p>{language==='tr'?'Zil Sesi Stüdyosu':'Ringtone Studio'}</p>
  </section>
}

const pages=[
  {titleTr:'Sesini içeri aktar', titleEn:'Import your sound',
    textTr:'Bir ses veya video seç. İstersen mikrofonunla kaydet.',
    textEn:'Choose an audio or video file. Or record with your microphone.'},
  {titleTr:'Tam istediğin anı seç', titleEn:'Choose the perfect moment',
    textTr:'1–29 saniyelik bölümünü seç. Kes, dinle ve sesine son dokunuşu yap.',
    textEn:'Choose a 1–29 second segment. Trim, listen and refine your sound.'},
  {titleTr:'Zil sesine dönüştür', titleEn:'Turn it into a ringtone',
    textTr:'Sesini WAV olarak dışa aktar. iPhone’da zil sesi yapmak için kurulum rehberini izle.',
    textEn:'Export your sound as WAV. Follow the setup guide to use it as a ringtone on iPhone.'},
] as const

// Illustrations only: not recorded media, live meters or interactive controls.
function WelcomeIllustration({page}:{page:number;language:Language}) {
  const Icon=page===0?FileAudio:page===1?Scissors:Bell
  return <div className={`w6-illustration w6-illustration-${page+1}`} aria-hidden="true">
    <span className="n4-welcome-symbol"><Icon size={52} strokeWidth={1.5}/></span>
    <div className="n4-welcome-detail">{page===0?<><Film size={24}/><Mic size={24}/></>:page===1?<AudioLines size={42} strokeWidth={1.2}/>:<FileCheck2 size={30}/>}</div>
  </div>
}

export function OnboardingScreen({language,onFinish}:{language:Language;onFinish:()=>void}) {
  const [page,setPage]=useState(0)
  const heading=useRef<HTMLHeadingElement>(null)
  const previousPage=useRef(page)
  const isTr=language==='tr',item=pages[page],isLast=page===pages.length-1
  useEffect(()=>{
    if(previousPage.current!==page){heading.current?.focus();previousPage.current=page}
  },[page])

  return <section className="onboarding-screen v2-screen v6-welcome v6-onboarding v3-screen v3-flow v3-onboarding" style={designVariables}
    aria-label={isTr?'Ringify tanıtımı':'Welcome to Ringify'}>
    <header className="w6-header">
      <LogoMark size={34} />
      <button type="button" className={`w6-skip${page===0?' w6-skip-initial':''}`} onClick={onFinish}>{isTr?'Geç':'Skip'}</button>
    </header>
    <div className="w6-scroll">
      <div className="w6-story" key={page}>
        <WelcomeIllustration page={page} language={language} />
        <div className="w6-copy">
          <span className="w6-step">0{page+1} / 03</span>
          <h1 ref={heading} tabIndex={-1}>{isTr?item.titleTr:item.titleEn}</h1>
          <p>{isTr?item.textTr:item.textEn}</p>
        </div>
      </div>
    </div>
    <footer className="w6-footer">
      <nav className="w6-pages" aria-label={isTr?'Tanıtım sayfaları':'Welcome pages'}>
        {pages.map((_,index)=><button type="button" key={index}
          onClick={()=>setPage(index)} aria-label={isTr?`${index+1}. sayfa`:`Page ${index+1}`}
          aria-current={index===page?'step':undefined}><span /></button>)}
      </nav>
      <div className="w6-actions">
        {page>0?<button type="button" className="w6-back" aria-label={isTr?'Geri':'Back'} onClick={()=>setPage(current=>current-1)}><ChevronLeft size={23} aria-hidden="true" /></button>:null}
        <PrimaryActionButton onClick={()=>isLast?onFinish():setPage(current=>current+1)}>
          {isLast?(isTr?'Başla':'Get Started'):(isTr?'İleri':'Next')}
        </PrimaryActionButton>
      </div>
    </footer>
  </section>
}
