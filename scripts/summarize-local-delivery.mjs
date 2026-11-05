// Summarize existing evidence. Does not run tests, install tools or publish.
import {readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve, join} from 'node:path';
import {execFileSync} from 'node:child_process';
const root = resolve(import.meta.dirname, '..');
async function read(file) {
  const bytes = await readFile(join(root, file));
  return bytes.toString(bytes[0] === 0xff && bytes[1] === 0xfe ? 'utf16le' : 'utf8').replace(/^\uFEFF/, '');
}
const json = async name => JSON.parse(await read(`design/review/${name}.json`));
const currentNativeFiles = execFileSync('git', ['ls-files','--cached','--others','--exclude-standard','-z','--','ios','packages/RingifyCore'],
  {cwd:root,encoding:'utf8'}).split('\0').filter(Boolean);
const tests = await json('final-web-tests'), audit = await json('final-npm-audit');
const scope = await json('native-studio-scope'), parser = await json('native-syntax'), release = await json('release-audit');
const buildLog = await read('design/review/final-web-build.log');
const swiftLog = await read('design/review/final-swift-test.log');
const addedXCTestFiles = ['StudioPresentationTests','StudioZoomRulesTests','StudioTrimRulesTests','StudioSelectionPersistenceTests'].map(name => `ios/RingifyTests/${name}.swift`);
const addedXCTestMethods = (await Promise.all(addedXCTestFiles.map(read)))
  .reduce((total, source) => total + [...source.matchAll(/^\s*func test\w+\(/gm)].length, 0);
const stale = [];
for (const [file, expected] of Object.entries(parser.files)) {
  if(createHash('sha256').update(await readFile(join(root,file))).digest('hex') !== expected) stale.push(file);
}
let coreEvidence;
try { coreEvidence = JSON.parse(await read('design/review/native-core-validation.json')); }
catch (error) { if(error.code !== 'ENOENT') throw error; }
const staleCore = [];
for (const [file, expected] of Object.entries(coreEvidence?.sourceHashes ?? {})) {
  if(createHash('sha256').update((await read(file)).replace(/\r\n/g,'\n')).digest('hex') !== expected) staleCore.push(file);
}
const testedCore = coreEvidence?.runs.find(run => run.id === coreEvidence.successfulRun);
const newCoreFiles = currentNativeFiles.filter(file=>file.startsWith('packages/RingifyCore/') && coreEvidence && !(file in coreEvidence.sourceHashes));
staleCore.push(...newCoreFiles.map(file=>`NEW: ${file}`));
const coreCurrent = testedCore?.conclusion === 'success' && Object.keys(coreEvidence.sourceHashes).length > 0 && staleCore.length === 0;
let actionsEvidence;
try { actionsEvidence = JSON.parse(await read('design/review/native-actions.json')); }
catch (error) { if(error.code !== 'ENOENT') throw error; }
const latestIOS = actionsEvidence?.runs.find(run => run.scope === 'ios');
const iosResult = latestIOS ? (latestIOS.status === 'completed' ? (latestIOS.conclusion === 'success' ? 'PASS' : 'FAIL') : latestIOS.status.toUpperCase()) : 'NOT_TESTED';
let iosEvidence;
try { iosEvidence = JSON.parse(await read('design/review/native-ios-validation.json')); }
catch (error) { if(error.code !== 'ENOENT') throw error; }
const lastIOSExecution = iosEvidence?.runs.at(-1);
const staleIOSSources = [];
// A newly added test/source also invalidates old evidence, even though it was
// absent from the older run's hash map. Include untracked, non-ignored files.
const untestedNewNativeFiles = currentNativeFiles.filter(file=>iosEvidence && !(file in iosEvidence.sourceHashes));
staleIOSSources.push(...untestedNewNativeFiles.map(file=>`NEW: ${file}`));
for(const [file,expected] of Object.entries(iosEvidence?.sourceHashes ?? {})) {
  const bytes = await readFile(join(root,file));
  const source = /\.(swift|yml|plist|json|strings|storekit|xcprivacy)$/.test(file) ? bytes.toString('utf8').replace(/\r\n/g,'\n') : bytes;
  if(createHash('sha256').update(source).digest('hex') !== expected) staleIOSSources.push(file);
}
const iosCurrent = lastIOSExecution?.debugBuild === 'PASS' && lastIOSExecution?.releaseBuild === 'PASS' && lastIOSExecution?.tests?.failed === 0 && Object.keys(iosEvidence.sourceHashes).length > 0 && staleIOSSources.length === 0;
const addedClasses = addedXCTestFiles.map(file=>file.split('/').at(-1).replace('.swift',''));
const recordedAddedCases = lastIOSExecution?.testCases.filter(test=>addedClasses.includes(test.suite)) ?? [];
const staleAddedTests = [];
for(const file of addedXCTestFiles) {
  if(iosEvidence && createHash('sha256').update((await read(file)).replace(/\r\n/g,'\n')).digest('hex') !== iosEvidence.sourceHashes[file]) staleAddedTests.push(file);
}
const addedResult = recordedAddedCases.length === addedXCTestMethods && recordedAddedCases.every(test=>test.result === 'PASS') && staleAddedTests.length === 0 ? 'PASS' : (recordedAddedCases.length ? 'FAIL_OR_RETEST_PENDING' : 'NOT_TESTED');
const report = {
  date: new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Istanbul',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date()), scope: 'Local source delivery; not App Store readiness or native runtime acceptance.',
  web: {testResult:tests.success && tests.numFailedTests === 0 ? 'PASS' : 'FAIL',
    passed:tests.numPassedTests,total:tests.numTotalTests,files:tests.testResults.length,
    build:/built in \d/.test(buildLog) ? 'PASS' : 'FAIL',
    dependencyAudit:audit.metadata?.vulnerabilities ?? null,
    dependencyAuditScope:'Previously recorded audit; dependencies and lockfile unchanged in this delivery.'},
  native: {implementation:'IMPLEMENTED_NOT_TESTED', parser:parser.passed && stale.length === 0 ? 'PASS' : 'FAIL',
    parsedFiles:Object.keys(parser.files).length,staleParserEvidence:stale,
    sourceChecks:{passed:scope.checks.filter(row=>row.passed).length,total:scope.checks.length,unchanged:scope.unchanged.length,changed:scope.changed.length,added:scope.added.length},
    releaseStaticChecks:{passed:release.checks.filter(row=>row.passed).length,total:release.checks.length},
    addedXCTestMethods,addedXCTestFiles,addedXCTestResult:addedResult,
    addedXCTestEvidence:lastIOSExecution ? {run:lastIOSExecution.id,passed:recordedAddedCases.filter(test=>test.result==='PASS').length,failed:recordedAddedCases.filter(test=>test.result==='FAIL').length,staleSources:staleAddedTests} : null,
    coreBuild:coreEvidence ? (coreCurrent ? testedCore.build : 'STALE_EVIDENCE') : 'FAIL: Windows manifest C runtime/header configuration (previous recorded attempt)',
    coreTest:coreEvidence ? (coreCurrent && testedCore.tests?.failed === 0 ? 'PASS' : 'REVIEW_LOG') : (/SwiftShims/.test(swiftLog) ? 'FAIL: Windows manifest SwiftShims; test runner did not start' : 'REVIEW_LOG'),
    coreMacEvidence:coreEvidence ? {run:coreEvidence.successfulRun,tests:testedCore?.tests,staleSources:staleCore} : null,
    iosWorkflow:latestIOS ? {result:iosResult,run:latestIOS.id,sha:latestIOS.sha,url:latestIOS.url,scope:'Recorded workflow result; physical device and visual acceptance are separate.'} : null,
    iosLastExecution:lastIOSExecution ? {run:lastIOSExecution.id,sha:lastIOSExecution.sha,debugBuild:lastIOSExecution.debugBuild,tests:lastIOSExecution.tests,releaseBuild:lastIOSExecution.releaseBuild,staleSources:staleIOSSources} : null,
    iosBuild:iosResult === 'PASS' && !iosCurrent ? 'STALE_EVIDENCE' : iosResult,
    runtimeAndVisualAcceptance:iosCurrent ? 'PARTIAL: native unit/fixture acceptance PASS; UI/device acceptance pending' : (coreEvidence ? 'NOT_TESTED' : 'BLOCKED_BY_MACOS')},
  releaseReady:false,
  userConfirmedPending:['Apple Developer Team ID','Real HTTPS privacy/support URLs','App Store Connect products'],
  remaining:[...(!iosCurrent ? [coreCurrent ? 'Apple SDK final tests and Release acceptance' : 'Core/Apple SDK build and tests'] : []),'Native simulator and device visual/accessibility acceptance',
    'AVFoundation codec/PCM/recording acceptance','SwiftData disk migration, journal and rollback acceptance',
    'StoreKit sandbox, 20 slot products, restore/refund/expiry','Signing, metadata, Archive, TestFlight and App Review'],
  evidence:['final-web-tests.json','final-web-build.log','final-npm-audit.json','native-studio-scope.json','release-audit.json','native-syntax.json','final-swift-test.log',...(coreEvidence?['native-core-validation.json']:[]),...(actionsEvidence?['native-actions.json']:[]),...(iosEvidence?['native-ios-validation.json']:[])]
};
await writeFile(join(root,'design/review/local-delivery.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
if(report.web.testResult !== 'PASS' || report.web.build !== 'PASS' || report.web.dependencyAudit?.total !== 0 ||
   report.native.parser !== 'PASS' || scope.checks.some(row=>!row.passed) || release.checks.some(row=>!row.passed)) process.exitCode=1;
