import { IDBFactory, IDBObjectStore } from 'fake-indexeddb'
import { describe, expect, it, vi } from 'vitest'
import { ProjectRepository, mediaBlob, projectSnapshot, storeMedia, type StoredProject } from './projectRepository'
import { emptyAudio } from '../test/audioFixtures'

const effects = { volume:0.6, fadeIn:0.3, fadeOut:0.4, normalize:true }
function record(id = 'one'): StoredProject {
  return { id, summary:{ id, name:'Voice', sourceName:'source.wav', duration:2, trimStart:1, trimEnd:3,
    updatedAt:'2026-10-31T10:00:00Z', status:'draft' }, sourceDuration:4, effects,
    source:{ bytes:new Uint8Array([1, 2, 3, 4]).buffer, type:'audio/wav' } }
}

describe('IndexedDB project integrity', () => {
  it('restores original source bytes, selection, effects and output after reopening', async () => {
    const factory = new IDBFactory()
    const repository = new ProjectRepository('round-trip', factory)
    const original = record()
    original.output = await storeMedia(new Blob([new Uint8Array([5, 6])], {type:'audio/wav'}))
    await repository.put(original)
    const restored = await new ProjectRepository('round-trip', factory).get('one')
    expect(restored).toEqual(original)
    expect(new Uint8Array(await mediaBlob(restored!.source!).arrayBuffer())).toEqual(new Uint8Array([1,2,3,4]))
  })
  it('preserves the last committed record if a write fails', async () => {
    const repository = new ProjectRepository('quota', new IDBFactory())
    await repository.put(record())
    const put = vi.spyOn(IDBObjectStore.prototype, 'put').mockImplementationOnce(() => { throw new DOMException('Quota exceeded', 'QuotaExceededError') })
    await expect(repository.put({...record(), effects:{...effects,volume:1.2}})).rejects.toThrow('Quota exceeded')
    put.mockRestore()
    expect((await repository.get('one'))!.effects).toEqual(effects)
  })
  it('does not overwrite durable edits during legacy migration', async () => {
    const repository = new ProjectRepository('migration', new IDBFactory())
    await repository.put(record())
    await repository.migrate([{...record().summary, name:'Old name'}])
    expect((await repository.get('one'))!.summary.name).toBe('Voice')
  })
  it('deletes source and output together without affecting another project', async () => {
    const repository = new ProjectRepository('delete', new IDBFactory())
    await repository.put(record('one')); await repository.put(record('two'))
    await repository.delete('one')
    expect(await repository.get('one')).toBeUndefined()
    expect(await repository.get('two')).toEqual(record('two'))
    await repository.clear()
    expect(await repository.list()).toEqual([])
  })
  it('invalidates an exported file only when the sound edits change', () => {
    const previous = {...record(), output:{bytes:new ArrayBuffer(2),type:'audio/wav'}, summary:{...record().summary,status:'exported' as const}}
    const editor = {projectID:'one', projectName:'Voice', trimStart:1, trimEnd:3, effects,
      asset:{fileName:'source.wav',duration:4,peaks:[],buffer:emptyAudio(1,400,100),isDemo:false}}
    expect(projectSnapshot(editor,previous).output).toEqual(previous.output)
    expect(projectSnapshot({...editor,effects:{...effects,volume:0.5}},previous).output).toBeUndefined()
    expect(projectSnapshot({...editor,trimEnd:2},previous).summary.status).toBe('draft')
  })
  it('surfaces unavailable storage rather than using an ephemeral fallback', async () => {
    const repository = new ProjectRepository('unavailable', null as unknown as IDBFactory)
    await expect(repository.put(record())).rejects.toThrow('IndexedDB unavailable')
  })
})
