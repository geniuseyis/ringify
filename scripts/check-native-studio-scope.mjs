// Source invariants, not Apple SDK compilation or native runtime acceptance.
import {readFile, readdir, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve, join} from 'node:path';
import {execFileSync} from 'node:child_process';
const root = resolve(import.meta.dirname, '..');
const read = file => readFile(join(root, file), 'utf8');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const baseline = JSON.parse(await read('design/review/native-studio-before.json'));
const allowed = new Set([
  'App/RootView.swift', 'DesignSystem/NativePresentationComponents.swift',
  'DesignSystem/RingifyComponents.swift', 'DesignSystem/RingifyTheme.swift',
  ...['AudioConversionView','AudioEditorView','AudioEffectsView','ExportView',
    'HelpAndErrorStatesView','HomeView','ImportSourceView','LibraryView','PremiumView',
    'PresentationSupportViews','RingtoneGuideView','RingtonePreviewView','SettingsView',
    'VoiceRecorderView'].map(name => `Screens/${name}.swift`)
].map(file => `ios/Ringify/${file}`));
// Approved P02 geometry/gesture package. Keep DSP, persistence and all other
// web modules protected rather than widening the entire preview scope.
for (const file of ['components/Waveform.tsx','components/Waveform.test.tsx','screens/StudioScreen.tsx','lib/waveformCoordinates.ts','lib/waveformCoordinates.test.ts']) {
  allowed.add(`preview/src/${file}`);
}
// Approved P04/P05 web-only PCM guards, playback rollback and bounded limiter.
// Native services, Core, IndexedDB and purchase sources remain protected.
for (const file of ['audioProcessing.ts','audioProcessing.test.ts','segmentPlayer.ts','segmentPlayer.test.ts','studioEffects.ts']) {
  allowed.add(`preview/src/lib/${file}`);
}
// Real macOS failure 41915100338: minimum Apple platforms and Int64.Stride.
allowed.add('packages/RingifyCore/Package.swift');
allowed.add('packages/RingifyCore/Sources/RingifyCore/AudioSegmentSuggestions.swift');
allowed.add('packages/RingifyCore/Tests/RingifyCoreTests/ProjectExportStateTests.swift');
// P09 recovery fault cases; ManagedFileDeletion production source is unchanged.
allowed.add('packages/RingifyCore/Tests/RingifyCoreTests/ManagedFileDeletionTests.swift');
// Real iOS failure 41916450785: delegate isolation and stale player regression.
allowed.add('ios/Ringify/Services/AVAudioPlaybackService.swift');
allowed.add('ios/RingifyTests/AudioIntegrityIntegrationTests.swift');
allowed.add('ios/RingifyTests/AudioConversionIntegrationTests.swift'); // Real MP4/AAC decode, energy and byte-preservation regression.
// Real Simulator run 41918375556: PCM finalization and typed issue assertions.
allowed.add('ios/project.yml'); // Resource phases were not being generated.
allowed.add('ios/Ringify/Services/AVAudioTrimService.swift');
allowed.add('ios/RingifyTests/AudioOutputIntegrationTests.swift');
allowed.add('ios/RingifyTests/AppModelIntegrityTests.swift');
allowed.add('ios/RingifyTests/BundleResourcesTests.swift'); // Assert built launch/privacy plist, not only source text.
// P08: isolated preferences and Debug-only UI bootstrap, not data/DSP changes.
allowed.add('ios/Ringify/App/AppModel.swift');
allowed.add('ios/Ringify/App/RingifyApp.swift');
// P09 only adds an optional isolated disk location; schema/transactions protected below.
allowed.add('ios/Ringify/Services/SwiftDataProjectStorageService.swift');
const additions = ['ios/Ringify/DesignSystem/RingifyStudioTheme.swift', 'ios/RingifyTests/StudioPresentationTests.swift',
  'ios/Ringify/DesignSystem/StudioZoomRules.swift', 'ios/RingifyTests/StudioZoomRulesTests.swift',
  'ios/Ringify/DesignSystem/StudioTrimRules.swift', 'ios/RingifyTests/StudioTrimRulesTests.swift',
  'ios/Ringify/Screens/StudioSelectionPersistence.swift','ios/RingifyTests/StudioSelectionPersistenceTests.swift',
  'preview/src/hooks/useWaveformPinchZoom.ts','preview/src/lib/waveformZoom.ts',
  'preview/src/lib/waveformZoom.test.ts','preview/src/components/WaveformPinch.test.tsx',
  'preview/src/lib/peakLimiter.test.ts',
  'ios/Ringify/Services/FinalizedPCMWriter.swift','ios/RingifyTests/BundleResourcesTests.swift',
  'ios/Ringify/Testing/UITestSupport.swift','ios/RingifyUITests/NativeScreenshotsTests.swift',
  'ios/RingifyTests/DiskStorageIntegrationTests.swift','ios/RingifyTests/LegacyProjectDiskFixture.swift'];
const checks = [], changed = [], unchanged = [], unexpected = [];
const check = (name, passed, evidence) => checks.push({name, passed: !!passed, evidence});
const modelPath = 'ios/Ringify/App/AppModel.swift';
const testedModel = execFileSync('git', ['show', `7e836d1:${modelPath}`], {cwd:root, encoding:'utf8'}).replace(/\r\n/g,'\n');
const expectedModel = testedModel
  .replace('    let container: AppContainer\n', '    let container: AppContainer\n    let preferenceStore: UserDefaults\n')
  .replace('init(container: AppContainer)', 'init(container: AppContainer, defaults: UserDefaults = .standard)')
  .replace('        self.container = container\n', '        self.container = container\n        preferenceStore = defaults\n')
  .replace('UserDefaults.standard.data(forKey:', 'defaults.data(forKey:')
  .replace('UserDefaults.standard.set(data,', 'preferenceStore.set(data,');
check('P08 AppModel differs from SDK-tested source only by preference injection',
  (await read(modelPath)).replace(/\r\n/g,'\n') === expectedModel,
  {baseline:'7e836d1', unchanged:'Project lifecycle, journals, saving, quotas, DSP and export rules'});
const storagePath = 'ios/Ringify/Services/SwiftDataProjectStorageService.swift';
const testedStorage = execFileSync('git', ['show', `7e836d1:${storagePath}`], {cwd:root, encoding:'utf8'}).replace(/\r\n/g,'\n');
const currentStorage = (await read(storagePath)).replace(/\r\n/g,'\n');
const newConfigStart = currentStorage.indexOf('        // A caller-owned disk URL');
const newConfigEnd = currentStorage.indexOf('        container = try ModelContainer', newConfigStart);
const restoredStorage = currentStorage.slice(0,newConfigStart)
  + '        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)\n'
  + currentStorage.slice(newConfigEnd);
check('P09 schema, migrations, journals and storage transactions unchanged', newConfigStart>=0 && newConfigEnd>newConfigStart
  && restoredStorage.replace('directories: AppDirectories? = nil, storeURL: URL? = nil)', 'directories: AppDirectories? = nil)')===testedStorage,
  {baseline:'7e836d1', change:'Optional isolated disk configuration only; production default unchanged'});
for (const [file, before] of Object.entries(baseline.hashes)) {
  try {
    const after = hash(await readFile(join(root, file)));
    if (before === after) unchanged.push(file);
    else { changed.push({file, before, after}); if (!allowed.has(file)) unexpected.push(file); }
  } catch (error) { unexpected.push(`${file}: ${error.code}`); }
}
check('No baseline source removed; changes confined to documented UI/audio/build fixes', unexpected.length === 0, {unexpected});
async function walk(folder) {
  const entries = await readdir(join(root, folder), {withFileTypes: true});
  return (await Promise.all(entries.map(row => row.isDirectory() ? walk(`${folder}/${row.name}`) : [`${folder}/${row.name}`]))).flat();
}
const current = (await Promise.all(['ios/Ringify','ios/RingifyTests','ios/RingifyUITests','preview/src','packages/RingifyCore/Sources','packages/RingifyCore/Tests'].map(walk))).flat();
const added = current.filter(file => !(file in baseline.hashes));
check('Only documented presentation, interaction and test sources added', added.length === additions.length && added.every(file => additions.includes(file)), added);
for (const [label, prefix] of Object.entries({web:'preview/', core:'packages/RingifyCore/', services:'ios/Ringify/Services/', viewModels:'ios/Ringify/ViewModels/', resources:'ios/Ringify/Resources/'})) {
  const files = Object.keys(baseline.hashes).filter(file => file.startsWith(prefix) && !allowed.has(file));
  check(`${label} protected files byte-for-byte unchanged`, files.length > 0 && files.every(file => unchanged.includes(file)), {files: files.length});
}
// These declarations contain no brace-bearing literal text; balanced extraction
// compares the complete approved palette/operation implementations, not snippets.
function block(source, marker) {
  const start = source.indexOf(marker);
  if (start < 0) throw Error(`Missing declaration: ${marker}`);
  const open = source.indexOf('{', start);
  let depth = 0;
  for (let i = open; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(start, i + 1);
  }
  throw Error(`Unbalanced declaration: ${marker}`);
}
const libraryFile = 'ios/Ringify/Screens/LibraryView.swift', library = await read(libraryFile);
for (const marker of ['private struct LibraryProjectDetailView:', 'private struct RenameProjectSheet:',
  'private func open(', 'private func toggleFavorite(', 'private func preferenceBinding<',
  'private func savePreferences(', 'private func reconcileCollectionFilter(', 'private func confirmDeletion(', 'private func endSelection(']) {
  check(`Approved project operation unchanged: ${marker}`, block(library, marker) === block(baseline.originals[libraryFile], marker));
}
const classicFile = 'ios/Ringify/DesignSystem/RingifyTheme.swift';
check('Classic Apple V2 palette unchanged', block(await read(classicFile), 'enum AppleV2 {') === block(baseline.originals[classicFile], 'enum AppleV2 {'));
check('Approved Splash and Onboarding unchanged', ['LaunchView','OnboardingView'].every(name => unchanged.includes(`ios/Ringify/Screens/${name}.swift`)));
const tokens = JSON.parse(await read('design/tokens.json')).appleVercel;
const theme = await read('ios/Ringify/DesignSystem/RingifyStudioTheme.swift');
const roleMap = {background:'background',surface:'surface',raised:'raised',text:'text',secondary:'secondary',muted:'muted',accent:'accent',soft:'accentSoft',border:'border',strongBorder:'borderStrong'};
for (const [native, key] of Object.entries(roleMap)) {
  const match = theme.match(new RegExp(`static let ${native} = adaptive\\(light: 0x([A-F0-9]{6}), dark: 0x([A-F0-9]{6})\\)`));
  check(`Native semantic token agrees: ${native}`, match && `#${match[1]}` === tokens.colors.light[key] && `#${match[2]}` === tokens.colors.dark[key]);
}
for (const [native, key] of Object.entries({action:null,canvas:'background',canvasBorder:'border',canvasText:'text',canvasSecondary:'secondary',wave:'wave',outsideWave:'outsideWave'})) {
  const match = theme.match(new RegExp(`static let ${native} = Color\\(uiColor: uiColor\\(0x([A-F0-9]{6})\\)\\)`));
  check(`Native fixed token agrees: ${native}`, match && `#${match[1]}` === (key ? tokens.canvas[key] : tokens.action));
}
for (const name of ['HomeView','ImportSourceView','VoiceRecorderView','AudioEditorView','AudioEffectsView','RingtonePreviewView','ExportView','RingtoneGuideView','LibraryView','PremiumView','SettingsView','HelpAndErrorStatesView','AudioConversionView']) {
  check(`Modern native root opts in: ${name}`, (await read(`ios/Ringify/Screens/${name}.swift`)).includes('.ringifyStudioAppearance()'));
}
const report = {scope:'Static source invariants only; no native runtime, typecheck, build or visual acceptance.', baselineFiles:Object.keys(baseline.hashes).length, unchanged, changed, added, checks, nativeStatus:'IMPLEMENTED_NOT_TESTED'};
await writeFile(join(root,'design/review/native-studio-scope.json'), JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({checks:checks.length,passed:checks.filter(row=>row.passed).length,unchanged:unchanged.length,changed:changed.length,added:added.length}));
if(checks.some(row=>!row.passed)) process.exitCode=1;
