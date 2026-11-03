// Source inventory and boundary audit only: no Swift test or media execution.
import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join,resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=file=>readFile(join(root,file),'utf8');
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const before=JSON.parse(await read('design/review/native-library-before.json'));
const allowed=new Set([
 'packages/RingifyCore/Sources/RingifyCore/DomainModels.swift',
 'packages/RingifyCore/Sources/RingifyCore/ProjectExportState.swift',
 'packages/RingifyCore/Sources/RingifyCore/ServiceProtocols.swift',
 'packages/RingifyCore/Tests/RingifyCoreTests/ProjectExportStateTests.swift',
 'ios/Ringify/Services/SwiftDataProjectStorageService.swift',
 'ios/Ringify/App/AppModel.swift','ios/Ringify/Screens/LibraryView.swift',
 'ios/RingifyTests/AppModelIntegrityTests.swift'
]);
const boundaries=[];
for(const[file,expected]of Object.entries(before.hashes)){
 const current=hash(await readFile(join(root,file)));
 boundaries.push({file,expected,current,intentionalChange:allowed.has(file),passed:allowed.has(file)||current===expected});
}
const parser=JSON.parse(await read('design/review/native-syntax.json'));
const parserHashes=[];
for(const[file,expected]of Object.entries(parser.files)){
 parserHashes.push({file,expected,current:hash(await readFile(join(root,file)))});
}
const testFiles={
 'packages/RingifyCore/Tests/RingifyCoreTests/LibraryModelsTests.swift':null,
 'packages/RingifyCore/Tests/RingifyCoreTests/ProjectExportStateTests.swift':[
  'testOrganizationKeepsActiveTokenAndCompletedAudioButContentInvalidates'],
 'ios/RingifyTests/LibraryStorageIntegrationTests.swift':null,
 'ios/RingifyTests/AppModelIntegrityTests.swift':[
  'testNewFavoriteAndCollectionCreationRequireVerifiedProWithoutChangingSavedProject',
  'testExpiredProCanRemoveOrganizationWithoutChangingAudioOrExportMetadata',
  'testOlderLibraryReadCannotOverwriteACommittedFavoriteRemoval',
  'testOrganizationDuringAnActiveExportKeepsProgressVisible',
  'testFailedDeleteReturnsFalseAndKeepsCurrentProjectForRetry']
};
const tests=[];
for(const[file,selected]of Object.entries(testFiles)){
 const body=await read(file),all=[...body.matchAll(/func (test\w+)\(/g)].map(match=>match[1]);
 for(const name of selected??all)tests.push({file,name,present:all.includes(name),result:'NOT_TESTED'});
}
const changed=boundaries.filter(row=>row.expected!==row.current);
const unchanged=boundaries.filter(row=>row.expected===row.current);
const passed=parser.passed&&parserHashes.every(row=>row.expected===row.current)&&boundaries.every(row=>row.passed)&&tests.every(row=>row.present);
const report={clientDate:'2026-11-02',scope:'Static source/hash inventory and actual parser evidence only. No executed SwiftData, DSP, StoreKit, UI or XCTest tests.',
 featureStatus:'IMPLEMENTED_NOT_TESTED',passed,baselineFiles:boundaries.length,
 unchangedFiles:unchanged.length,unchangedWebSources:unchanged.filter(row=>row.file.startsWith('preview/src/')).length,
 intentionalChanges:changed.filter(row=>row.intentionalChange),unexpectedChanges:boundaries.filter(row=>!row.passed),
 newSwiftFiles:parserHashes.filter(row=>!before.hashes[row.file]).map(row=>row.file),
 parser:{passed:parser.passed,files:parserHashes.length,currentHashes:parserHashes},
 addedTestMethods:tests.length,tests,boundaries,
 coreBuild:'Previous manifest failure: stdlib.h / SwiftShims; not rerun.',coreTests:'NOT_TESTED',
 nativeBuild:'NOT_TESTED',nativeTests:'NOT_TESTED',nativeAcceptance:'BLOCKED_BY_MACOS',
 webBuildAndTests:'Unchanged sources/lockfile; previous 362-test run, not rerun.'};
await writeFile(join(root,'design/review/native-library-scope.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({sourceBoundaryPassed:passed,unchangedFiles:report.unchangedFiles,
 intentionalChanges:report.intentionalChanges.length,unchangedWebSources:report.unchangedWebSources,
 parserFiles:parserHashes.length,newSwiftFiles:report.newSwiftFiles.length,newTestMethods:tests.length,testResult:'NOT_TESTED'}));
if(!passed)process.exitCode=1;
