// Limited local workflow guards and Bash parsing. Not a GitHub Actions run.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {resolve,join} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const text=await readFile(join(root,'.github/workflows/native-validation.yml'),'utf8');
const checks=[];
function check(name,passed){checks.push({name,passed:!!passed})}
check('Manual trigger only',text.includes('  workflow_dispatch:')&&!/^  (push|pull_request|schedule|pull_request_target):/m.test(text));
check('Read-only contents and no checkout credentials',text.includes('  contents: read')&&text.includes('persist-credentials: false'));
check('Bounded standard runner with core default',text.includes('runs-on: macos-26')&&text.includes('timeout-minutes: 35')&&text.includes('default: core'));
check('No error masking',!text.includes('continue-on-error:')&&!text.includes('|| true'));
const actions=[...text.matchAll(/uses: (\S+)/g)].map(row=>row[1]);
check('Actions pinned to full commit IDs',actions.length===3&&actions.every(value=>/@[a-f0-9]{40}$/.test(value)));
check('Separate screenshots only for UI and still uploaded on failure',text.includes("if: always() && inputs.scope == 'ui'")
  &&text.includes('name: native-ui-screenshots-${{ github.run_id }}')&&text.includes('path: artifacts/native-ui/'));
check('Both evidence artifacts have bounded retention',(text.match(/retention-days: 3/g)??[]).length===2);
check('Project generation preserves the reviewed application plist',text.includes('git diff --exit-code -- ios/Ringify/Supporting/Info.plist'));
check('Core build and test, native debug test and release build',text.includes('swift build --package-path packages/RingifyCore')&&text.includes('swift test --package-path packages/RingifyCore')&&text.includes('CODE_SIGNING_ALLOWED=NO test')&&text.includes('CODE_SIGNING_ALLOWED=NO build'));
check('Results saved even after failure, retained briefly',text.includes('if: always()')&&text.includes('retention-days: 3')&&text.includes('artifacts/Tests.xcresult'));
const folder=join(root,'.git/ringify-day2-20261104/ci-shell');await mkdir(folder,{recursive:true});
const lines=text.split('\n'),scripts=[];
for(let i=0;i<lines.length;i++)if(/^        run: \|$/.test(lines[i])){
 const script=[];while(++i<lines.length&&(lines[i].startsWith('          ')||!lines[i].trim()))script.push(lines[i].slice(10));i--;scripts.push(script.join('\n')+'\n');
}
check('All five shell blocks found',scripts.length===5);
for(let i=0;i<scripts.length;i++){
 const file=join(folder,`step-${i+1}.sh`);await writeFile(file,scripts[i]);
 const result=spawnSync(process.platform==='win32'?'C:/Program Files/Git/bin/bash.exe':'bash',['-n',file],{encoding:'utf8',windowsHide:true});
 check(`Bash syntax block ${i+1}`,result.status===0&&!result.error);
 if(result.status!==0)console.error(result.stderr||result.error?.message);
}
const report={scope:'Local source guards and bash -n, not complete Actions schema/runner validation.',checks,remoteRun:'NOT_TESTED'};
await writeFile(join(root,'design/review/native-ci-local.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({checks:checks.length,passed:checks.filter(row=>row.passed).length,remoteRun:'NOT_TESTED'}));
if(checks.some(row=>!row.passed))process.exitCode=1;
