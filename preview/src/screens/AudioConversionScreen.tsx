import {useRef,useState} from 'react'
import {ArrowDownToLine,ArrowRightLeft,FileAudio,LoaderCircle,Share2} from 'lucide-react'
import type {Language} from '../types'
import {ScreenShell} from '../components/ScreenShell'
import {designVariables} from '../designSystem/tokens'
import {PrimaryActionButton,SecondaryActionButton} from '../designSystem/StudioComponents'
import {ConversionError} from '../lib/audioConversion'
import {formatTime,sanitizeFileName} from '../lib/format'
import {shareAudioFile} from '../lib/sharing'
import {useAudioConversion} from '../hooks/useAudioConversion'
import '../designSystem/conversion.css'

const messages={
  type:['MP3 veya MP4 dosyası seç. Dosya içeriği de biçimle eşleşmeli.','Choose an MP3 or MP4 whose contents match its format.'],
  size:['Boş olmayan, en fazla 32 MB bir dosya seç.','Choose a nonempty file up to 32 MB.'],
  duration:['Web dönüşümünde en fazla 2 dakikalık, geçerli süreli medya kullan.','Web conversion supports valid media up to 2 minutes.'],
  channels:['Mono veya stereo ses kullan. Çok kanallı kaynak desteklenmiyor.','Use mono or stereo audio. Multichannel sources are not supported.'],
  codec:['Ses izi bulunamadı veya bu tarayıcı codec’i çözemedi. Başka bir dosya dene.','No decodable audio track was found. Try another file.'],
  memory:['Bu dosyanın açılmış ses verisi bellek sınırını aşıyor. Daha kısa bir kaynak seç.','Decoded audio exceeds the memory limit. Choose a shorter source.'],
  samples:['Ses verisi geçersiz; dosya dönüştürülemedi.','Invalid audio samples. The file could not be converted.'],
  verification:['Çıktı doğrulanamadı. Yeniden dene veya başka bir dosya seç.','Output verification failed. Retry or choose another file.'],
} as const
export function AudioConversionScreen({language,onBack}:{language:Language;onBack:()=>void}){
  const tr=language==='tr',conversion=useAudioConversion(),picker=useRef<HTMLInputElement>(null)
  const [file,setFile]=useState<File|null>(null),[name,setName]=useState(''),[shareError,setShareError]=useState(false)
  const stageText={idle:'',success:'',error:'',reading:tr?'Dosya doğrulanıyor…':'Validating file…',decoding:tr?'Ses açılıyor…':'Decoding audio…',encoding:tr?'WAV hazırlanıyor…':'Encoding WAV…',verifying:tr?'Çıktı doğrulanıyor…':'Verifying output…'}
  const errorCode=conversion.error instanceof ConversionError?conversion.error.code:'codec'
  const outputName=sanitizeFileName(name)
  function choose(next:File){conversion.reset();setShareError(false);setFile(next);setName(next.name.replace(/\.[^.]+$/,''))}
  async function share(){if(!conversion.result)return;setShareError(false);try{await shareAudioFile(conversion.result.blob,outputName)}catch{setShareError(true)}}
  return <ScreenShell title={tr?'Ses Dönüştür':'Convert Audio'} onBack={onBack} backLabel={tr?'Geri':'Back'} className="v2-screen v3-screen v3-flow v3-conversion av-screen av-finish av-conversion" style={designVariables}>
    <div className="conversion-heading"><span aria-hidden="true"><ArrowRightLeft size={30}/></span><h2>{tr?'Videodan sese. Sesten WAV’a.':'Video to audio. Audio to WAV.'}</h2><p>{tr?'MP4 veya MP3 dosyanın tamamını dönüştür. Kaynak dosyan değişmez.':'Convert your entire MP4 or MP3. Your original file stays unchanged.'}</p></div>
    <button type="button" className="conversion-picker" disabled={conversion.busy} onClick={()=>picker.current?.click()}><FileAudio size={25} aria-hidden="true"/><span>{file?file.name:(tr?'MP4 veya MP3 seç':'Choose MP4 or MP3')}</span></button>
    <input className="sr-only" ref={picker} type="file" accept=".mp4,.mp3,video/mp4,audio/mpeg" aria-label={tr?'Dönüştürülecek dosya':'File to convert'} onChange={event=>{const next=event.currentTarget.files?.[0];event.currentTarget.value='';if(next)choose(next)}}/>
    <section className="conversion-format" aria-label={tr?'Çıktı biçimleri':'Output formats'}><div><strong>WAV / PCM 16-bit</strong><span>{tr?'Tarayıcıda kullanılabilir':'Available in this browser'}</span></div><div><strong>M4A / AAC</strong><span>{tr?'Native iOS uygulamasında':'In the native iOS app'}</span></div></section>
    <p className="conversion-limits">{tr?'Web: en fazla 32 MB, 2 dakika, mono/stereo. WAV’a dönüşüm kayıplı kaydın kalitesini artırmaz.':'Web: up to 32 MB, 2 minutes, mono/stereo. WAV conversion does not restore lost audio quality.'}</p>
    <label className="conversion-name">{tr?'Çıktı dosyası adı':'Output file name'}<input value={name} maxLength={64} disabled={conversion.busy} onChange={event=>setName(event.target.value)}/></label>
    {conversion.busy?<div role="status" className="conversion-status"><LoaderCircle className="spin" size={22} aria-hidden="true"/>{stageText[conversion.stage]}</div>:null}
    {conversion.stage==='error'?<p role="alert" className="inline-error">{messages[errorCode][tr?0:1]}</p>:null}
    {conversion.result?<section className="conversion-result"><h2>{tr?'Dosyan hazır':'Your file is ready'}</h2><p>{formatTime(conversion.result.duration)} · {conversion.result.sampleRate/1000} kHz · {conversion.result.channels===1?'Mono':'Stereo'} · {(conversion.result.blob.size/1024/1024).toFixed(2)} MB</p><audio controls src={conversion.result.url} aria-label={tr?'Dönüştürülen sesi dinle':'Listen to converted audio'}/><a className="r-action r-primary" href={conversion.result.url} download={`${outputName||'Ringify'}.wav`}><ArrowDownToLine size={20} aria-hidden="true"/>{tr?'WAV Dosyasını İndir':'Download WAV'}</a><SecondaryActionButton onClick={()=>void share()} disabled={!outputName} icon={<Share2 size={20} aria-hidden="true"/>}>{tr?'Paylaş':'Share'}</SecondaryActionButton>{shareError?<p role="alert">{tr?'Paylaşım tamamlanamadı. Dosyayı indirerek saklayabilirsin.':'Sharing failed. You can download the file instead.'}</p>:null}</section>:conversion.busy?<SecondaryActionButton onClick={conversion.reset}>{tr?'İptal':'Cancel'}</SecondaryActionButton>:<PrimaryActionButton disabled={!file||!outputName} onClick={()=>{if(file)void conversion.start(file)}}>{conversion.stage==='error'?(tr?'Yeniden Dene':'Retry'):(tr?'WAV’a Dönüştür':'Convert to WAV')}</PrimaryActionButton>}
  </ScreenShell>
}
