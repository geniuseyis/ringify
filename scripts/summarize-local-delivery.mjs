// Summarize existing evidence. Does not run tests, install tools or publish.
import {readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve, join} from 'node:path';
const root = resolve(import.meta.dirname, '..');
async function read(file) {
  const bytes = await readFile(join(root, file));
  return bytes.toString(bytes[0] === 0xff && bytes[1] === 0xfe ? 'utf16le' : 'utf8').replace(/^\uFEFF/, '');
}
const json = async name => JSON.parse(await read(`design/review/${name}.json`));
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
const report = {
  date: '2026-11-04', scope: 'Local source delivery; not App Store readiness or native runtime acceptance.',
  web: {testResult:tests.success && tests.numFailedTests === 0 ? 'PASS' : 'FAIL',
    passed:tests.numPassedTests,total:tests.numTotalTests,files:tests.testResults.length,
    build:/built in \d/.test(buildLog) ? 'PASS' : 'FAIL',
    dependencyAudit:audit.metadata?.vulnerabilities ?? null},
  native: {implementation:'IMPLEMENTED_NOT_TESTED', parser:parser.passed && stale.length === 0 ? 'PASS' : 'FAIL',
    parsedFiles:Object.keys(parser.files).length,staleParserEvidence:stale,
    sourceChecks:{passed:scope.checks.filter(row=>row.passed).length,total:scope.checks.length,unchanged:scope.unchanged.length,changed:scope.changed.length,added:scope.added.length},
    releaseStaticChecks:{passed:release.checks.filter(row=>row.passed).length,total:release.checks.length},
    addedXCTestMethods,addedXCTestFiles,addedXCTestResult:'NOT_TESTED',
    coreBuild:'FAIL: manifest C runtime/header configuration (previous recorded attempt; not rerun without environment changes)',
    coreTest: /SwiftShims/.test(swiftLog) ? 'FAIL: manifest SwiftShims; test runner did not start' : 'REVIEW_LOG',
    iosBuild:'NOT_TESTED',runtimeAndVisualAcceptance:'BLOCKED_BY_MACOS'},
  releaseReady:false,
  userConfirmedPending:['Apple Developer Team ID','Real HTTPS privacy/support URLs','App Store Connect products'],
  remaining:['Core/Apple SDK build and tests','Native simulator and device visual/accessibility acceptance',
    'AVFoundation codec/PCM/recording acceptance','SwiftData disk migration, journal and rollback acceptance',
    'StoreKit sandbox, 20 slot products, restore/refund/expiry','Signing, metadata, Archive, TestFlight and App Review'],
  evidence:['final-web-tests.json','final-web-build.log','final-npm-audit.json','native-studio-scope.json','release-audit.json','native-syntax.json','final-swift-test.log']
};
await writeFile(join(root,'design/review/local-delivery.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
if(report.web.testResult !== 'PASS' || report.web.build !== 'PASS' || report.web.dependencyAudit?.total !== 0 ||
   report.native.parser !== 'PASS' || scope.checks.some(row=>!row.passed) || release.checks.some(row=>!row.passed)) process.exitCode=1;
