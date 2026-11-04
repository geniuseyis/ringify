// Source invariants, not Apple SDK compilation or native runtime acceptance.
import {readFile, readdir, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve, join} from 'node:path';
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
const additions = ['ios/Ringify/DesignSystem/RingifyStudioTheme.swift', 'ios/RingifyTests/StudioPresentationTests.swift'];
const checks = [], changed = [], unchanged = [], unexpected = [];
const check = (name, passed, evidence) => checks.push({name, passed: !!passed, evidence});
for (const [file, before] of Object.entries(baseline.hashes)) {
  try {
    const after = hash(await readFile(join(root, file)));
    if (before === after) unchanged.push(file);
    else { changed.push({file, before, after}); if (!allowed.has(file)) unexpected.push(file); }
  } catch (error) { unexpected.push(`${file}: ${error.code}`); }
}
check('No baseline source removed; changes confined to presentation allowlist', unexpected.length === 0, {unexpected});
async function walk(folder) {
  const entries = await readdir(join(root, folder), {withFileTypes: true});
  return (await Promise.all(entries.map(row => row.isDirectory() ? walk(`${folder}/${row.name}`) : [`${folder}/${row.name}`]))).flat();
}
const current = (await Promise.all(['ios/Ringify','ios/RingifyTests','preview/src','packages/RingifyCore/Sources','packages/RingifyCore/Tests'].map(walk))).flat();
const added = current.filter(file => !(file in baseline.hashes));
check('Only documented native theme and XCTest sources added', added.length === additions.length && added.every(file => additions.includes(file)), added);
for (const [label, prefix] of Object.entries({web:'preview/', core:'packages/RingifyCore/', services:'ios/Ringify/Services/', viewModels:'ios/Ringify/ViewModels/', resources:'ios/Ringify/Resources/'})) {
  const files = Object.keys(baseline.hashes).filter(file => file.startsWith(prefix));
  check(`${label} byte-for-byte unchanged`, files.length > 0 && files.every(file => unchanged.includes(file)), {files: files.length});
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
