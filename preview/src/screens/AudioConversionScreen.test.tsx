import {cleanup,fireEvent,render,screen} from '@testing-library/react'
import {afterEach,beforeEach,describe,expect,it,vi} from 'vitest'
import {AudioConversionScreen} from './AudioConversionScreen'
import {ImportScreen} from './CaptureScreens'
import {useAudioConversion} from '../hooks/useAudioConversion'
vi.mock('../hooks/useAudioConversion',()=>({useAudioConversion:vi.fn()}))
const job={stage:'idle' as const,error:null,result:null,busy:false,start:vi.fn(),reset:vi.fn()}
beforeEach(()=>{vi.clearAllMocks();vi.mocked(useAudioConversion).mockReturnValue({...job})})
afterEach(cleanup)
describe('Audio conversion presentation',()=>{
 it('routes Import to a conversion flow without replacing project data or choosing a fake source',()=>{
  const navigate=vi.fn(),choose=vi.fn();render(<ImportScreen language="tr" isLoading={false} error={null} onBack={()=>{}} onChooseFile={choose} onUseDemo={()=>{}} onClearError={()=>{}} onNavigate={navigate}/>)
  fireEvent.click(screen.getByRole('button',{name:'Ses Dönüştür'}));expect(navigate).toHaveBeenCalledExactlyOnceWith('conversion');expect(choose).not.toHaveBeenCalled()
 })
 it('requires a real file, forwards it unchanged, clears stale results on reselect and never offers browser M4A',()=>{
  render(<AudioConversionScreen language="tr" onBack={()=>{}}/>);expect(screen.getByRole('button',{name:'WAV’a Dönüştür'})).toBeDisabled()
  const file=new File(['original'],'voice.mp3',{type:'audio/mpeg'}),picker=screen.getByLabelText('Dönüştürülecek dosya')
  fireEvent.change(picker,{target:{files:[file]}});expect(job.reset).toHaveBeenCalledOnce()
  fireEvent.click(screen.getByRole('button',{name:'WAV’a Dönüştür'}));expect(job.start).toHaveBeenCalledExactlyOnceWith(file)
  expect(screen.getByText('Native iOS uygulamasında')).toBeInTheDocument();expect(screen.queryByRole('button',{name:/M4A/})).not.toBeInTheDocument()
 })
 it('exposes real cancellation and disables changing input while work is active',()=>{
  vi.mocked(useAudioConversion).mockReturnValue({...job,stage:'encoding',busy:true})
  render(<AudioConversionScreen language="tr" onBack={()=>{}}/>);expect(screen.getByRole('status')).toHaveTextContent('WAV hazırlanıyor')
  expect(screen.getByRole('button',{name:'MP4 veya MP3 seç'})).toBeDisabled();fireEvent.click(screen.getByRole('button',{name:'İptal'}));expect(job.reset).toHaveBeenCalledOnce()
 })
 it('localizes the conversion route and back action into English',()=>{
  const back=vi.fn();render(<AudioConversionScreen language="en" onBack={back}/>);expect(screen.getByRole('heading',{name:'Convert Audio'})).toBeInTheDocument()
  fireEvent.click(screen.getByRole('button',{name:'Back'}));expect(back).toHaveBeenCalledOnce();expect(screen.getByText(/WAV conversion does not restore/)).toBeInTheDocument()
 })
})
