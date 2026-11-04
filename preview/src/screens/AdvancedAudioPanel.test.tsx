import {act,cleanup,fireEvent,render,screen} from '@testing-library/react'
import {afterEach,beforeEach,expect,it,vi} from 'vitest'
import {AdvancedAudioPanel} from './AdvancedAudioPanel'
import {neutralStudio} from '../lib/studioEffects'
import {audioFixture} from '../test/audioFixtures'
import type {EditorState} from '../types'
let job:TestWorker
class TestWorker {onmessage:((event:{data:unknown})=>void)|null=null;onerror:(()=>void)|null=null;terminate=vi.fn();postMessage=vi.fn();constructor(){job=this}}
beforeEach(()=>vi.stubGlobal('Worker',TestWorker))
afterEach(()=>{cleanup();vi.unstubAllGlobals()})
function editor():EditorState{return{projectID:'source',projectName:'source',asset:{fileName:'source.wav',duration:3,peaks:[],isDemo:false,buffer:audioFixture([Array<number>(24000).fill(.1)],8000)},trimStart:.5,trimEnd:2.5,effects:{volume:1,fadeIn:0,fadeOut:0,normalize:false}}}
function open(){fireEvent.click(screen.getByText('Gelişmiş ses araçları'))}
it('routes locked tools to Pro without changing media or granting an entitlement',()=>{
 const change=vi.fn(),requirePro=vi.fn();render(<AdvancedAudioPanel language="tr" editor={editor()} enabled={false} onChange={change} onRequirePro={requirePro}/>)
 fireEvent.click(screen.getByRole('button',{name:/EQ, filtreler/}));expect(requirePro).toHaveBeenCalledOnce();expect(change).not.toHaveBeenCalled();expect(screen.queryByRole('slider')).not.toBeInTheDocument()
})
it('updates real parameters and presets without mutating the source or changing trim',()=>{
 const source=editor(),change=vi.fn();render(<AdvancedAudioPanel language="tr" editor={source} enabled onChange={change}/>);open()
 fireEvent.change(screen.getByRole('slider',{name:'EQ 1 kHz'}),{target:{value:'6'}})
 expect(change.mock.lastCall![0]).toMatchObject({trimStart:.5,trimEnd:2.5,effects:{studio:{mid:6}}});expect(change.mock.lastCall![0].asset).toBe(source.asset)
 fireEvent.change(screen.getByRole('combobox',{name:'Ses karakteri'}),{target:{value:'telephone'}})
 expect(change.mock.lastCall![0].effects.studio).toEqual({...neutralStudio,highPass:300,lowPass:3400,channels:'mono'})
 expect(source.effects.studio).toBeUndefined()
})
it('copies only the selected PCM to a worker, applies a suggestion in source coordinates and cancels stale analysis',()=>{
 const source=editor(),change=vi.fn(),view=render(<AdvancedAudioPanel language="tr" editor={source} enabled onChange={change}/>);open()
 fireEvent.click(screen.getByRole('button',{name:'Seçimi analiz et'}));expect(job.postMessage.mock.calls[0][0].channels[0]).toHaveLength(16000)
 act(()=>job.onmessage!({data:{result:{peakDbFS:-6,rmsDbFS:-9,duration:2,silentRegions:[{start:0,end:.3}],suggestion:{start:.3,end:1.8}}}}))
 fireEvent.click(screen.getByRole('button',{name:'Baş/son sessizliğini kes'}));expect(change.mock.lastCall![0]).toMatchObject({trimStart:.8,trimEnd:2.3})
 fireEvent.click(screen.getByRole('button',{name:'Seçimi analiz et'}));const old=job
 view.rerender(<AdvancedAudioPanel language="tr" editor={{...source,trimStart:.8}} enabled onChange={change}/>);expect(old.terminate).toHaveBeenCalled()
 act(()=>old.onmessage!({data:{result:{peakDbFS:0,suggestion:{start:0,end:2}}}}))
 expect(screen.queryByRole('button',{name:'Baş/son sessizliğini kes'})).not.toBeInTheDocument()
})
it('offers recovery for invalid persisted parameters without deleting the source',()=>{
 const source=editor(),change=vi.fn();source.effects.studio={...neutralStudio,lowPass:NaN}
 render(<AdvancedAudioPanel language="tr" editor={source} enabled={false} onChange={change}/>);expect(screen.getByRole('alert')).toHaveTextContent('Kaynak sesin korunuyor')
 fireEvent.click(screen.getByRole('button',{name:'Gelişmiş ayarları temizle'}));expect(change.mock.lastCall![0].effects.studio).toBeUndefined();expect(change.mock.lastCall![0].asset).toBe(source.asset)
})
it('terminates analysis on explicit cancellation and ignores its late reply',()=>{
 render(<AdvancedAudioPanel language="tr" editor={editor()} enabled onChange={vi.fn()}/>);open()
 fireEvent.click(screen.getByRole('button',{name:'Seçimi analiz et'}));const old=job
 fireEvent.click(screen.getByRole('button',{name:'Analizi iptal et'}));expect(old.terminate).toHaveBeenCalledOnce()
 act(()=>old.onmessage!({data:{result:{peakDbFS:0,suggestion:{start:0,end:2}}}}))
 expect(screen.queryByRole('status')).not.toBeInTheDocument();expect(screen.queryByRole('button',{name:'Baş/son sessizliğini kes'})).not.toBeInTheDocument()
})
