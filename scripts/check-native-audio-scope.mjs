// Source boundaries only. This does not execute Swift, DSP or persistence tests.
import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join,resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=file=>readFile(join(root,file),'utf8');
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const before=JSON.parse(await read('design/review/native-remaining-ui-before.json'));
const allowed=new Set([
 'packages/RingifyCore/Sources/RingifyCore/AudioGainEnvelope.swift',
 'packages/RingifyCore/Sources/RingifyCore/DomainModels.swift',
 'packages/RingifyCore/Sources/RingifyCore/ProAccessPolicy.swift',
 'ios/Ringify/Services/AVAudioEffectsService.swift',
 'ios/Ringify/Services/SwiftDataProjectStorageService.swift',
 'ios/Ringify/App/AppModel.swift',
 'ios/Ringify/Screens/AudioEditorView.swift',
 'ios/Ringify/Resources/tr.lproj/Localizable.strings',
 'ios/Ringify/Resources/en.lproj/Localizable.strings'
]);
const boundaries=[];
for(const[file,previous]of Object.entries(before.protectedHashes)){
 const current=hash(await readFile(join(root,file)));
 boundaries.push({file,previous,current,intentionalChange:allowed.has(file),passed:allowed.has(file)||current===previous});
}
function methodBody(source,name){
 const start=new RegExp('private func '+name+'\\(').exec(source)?.index;
 if(start===undefined)throw Error('Missing method '+name);
 const open=source.indexOf('{',start);let depth=0;
 for(let i=open;i<source.length;i++){
  if(source[i]==='{')depth++;
  if(source[i]==='}'&&--depth===0)return source.slice(start,i+1);
 }
 throw Error('Unbalanced method '+name);
}
const methods=[];
for(const[key,previous]of Object.entries(before.methodHashes)){
 const[file,name]=key.split('#'),current=hash(Buffer.from(methodBody(await read(file),name)));
 methods.push({method:key,previous,current,passed:previous===current});
}
const syntax=JSON.parse(await read('design/review/native-syntax.json'));
const parserHashes=[];
for(const[file,expected]of Object.entries(syntax.files))parserHashes.push({file,passed:hash(await readFile(join(root,file)))===expected});
const testSources={
 'packages/RingifyCore/Tests/RingifyCoreTests/StudioAudioProcessorTests.swift':null,
 'ios/RingifyTests/SwiftDataProjectStorageServiceTests.swift':[
  'testAdvancedSettingsRoundTripAndResetPreserveProjectMetadata','testLegacyNilStudioMetadataKeepsExistingEffects',
  'testCorruptStudioMetadataFailsInsteadOfDroppingEffects','testInvalidSettingsCannotPartiallyUpdateStoredProject'],
 'ios/RingifyTests/AppModelIntegrityTests.swift':[
  'testRejectedAdvancedEditKeepsProjectAndDoesNotQueueStorage',
  'testSavedAdvancedSettingsSurviveBasicEditWithoutProAndCanBeReset',
  'testInvalidAdvancedEditIsRejectedBeforeChangingCurrentProject'],
 'ios/RingifyTests/AudioIntegrityIntegrationTests.swift':[
  'testAdvancedEffectsProduceStereoAudioWithoutChangingSourceOrDuration',
  'testEffectsRejectFrequenciesAboveActualSourceNyquistWithoutCreatingOutput']
};
const tests=[];
for(const[file,selected]of Object.entries(testSources)){
 const source=await read(file),names=[...source.matchAll(/func (test\w+)\(/g)].map(match=>match[1]);
 for(const name of selected??names)tests.push({file,name,present:names.includes(name),result:'NOT_TESTED'});
}
const localizations=[];
for(const language of ['tr','en']){
 const source=await read(`ios/Ringify/Resources/${language}.lproj/Localizable.strings`);
 const keys=[...source.matchAll(/^"([^"]+)"\s*=/gm)].map(match=>match[1]);
 localizations.push({language,keys:keys.length,unique:new Set(keys).size===keys.length,
  studioKey:keys.includes('premium.studio.required')});
}
const passed=syntax.passed&&parserHashes.every(row=>row.passed)&&boundaries.every(row=>row.passed)&&
 methods.every(row=>row.passed)&&tests.every(row=>row.present)&&localizations.every(row=>row.unique&&row.studioKey);
const report={clientDate:'2026-11-02',scope:'Static source/hash/localization checks only. Not executed DSP, SwiftData, StoreKit or UI tests.',
 featureStatus:'IMPLEMENTED_NOT_TESTED',passed,
 protectedBaseline:boundaries.length,unchangedProtectedFiles:boundaries.filter(row=>row.previous===row.current).length,
 intentionalChanges:boundaries.filter(row=>row.previous!==row.current&&row.intentionalChange),
 unexpectedChanges:boundaries.filter(row=>!row.passed),
 unchangedWebSources:boundaries.filter(row=>row.file.startsWith('preview/src/')&&row.current===row.previous).length,
 boundaries,methods,parser:{passed:syntax.passed,files:parserHashes.length,currentHashes:parserHashes},
 addedTestMethods:tests.length,tests,localizations,nativeBuild:'NOT_TESTED',nativeTests:'NOT_TESTED'};
await writeFile(join(root,'design/review/native-advanced-audio-scope.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({sourceBoundaryPassed:passed,unchangedProtectedFiles:report.unchangedProtectedFiles,
 intentionalChanges:report.intentionalChanges.length,unchangedWebSources:report.unchangedWebSources,
 preservedMethods:methods.length,parserFiles:parserHashes.length,newTestMethods:tests.length,testResult:'NOT_TESTED'}));
if(!passed)process.exitCode=1;
