import * as audio from '../lib/audio'
import type {renderSelectionExport} from '../lib/selectionExport'

// jsdom has no real module Worker. Keep real DSP/encoding for hook/App tests;
// worker transfer/termination is separately protocol-tested and browser-tested.
export const selectionExportFixture:typeof renderSelectionExport=async(buffer,start,end,effects,bitDepth,signal,onStage)=>{
  await new Promise<void>(resolve=>setTimeout(resolve,0))
  if(signal.aborted)throw new DOMException('Cancelled','AbortError')
  onStage('processing')
  return audio.encodeSelectionAsWav(buffer,start,end,effects,bitDepth)
}
