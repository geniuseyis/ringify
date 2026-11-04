import {readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {resolve,join} from 'node:path';
import {isDeepStrictEqual} from 'node:util';
const root=resolve(import.meta.dirname,'..');
const read=path=>readFile(join(root,path),'utf8');
const before=JSON.parse(await read('design/review/apple-vercel-source-before.json'));
const report={scope:'Home V2 / Studio presentation only; no DSP, persistence or native changes',checks:[],contrast:[]};
const check=(name,passed,evidence)=>report.checks.push({name,passed:!!passed,evidence});
const mismatches=[];
for(const [path,hash] of Object.entries(before.hashes)){
 const actual=createHash('sha256').update(await readFile(join(root,path))).digest('hex');
 if(actual!==hash)mismatches.push(path);
}
check('All protected audio, hooks, data, Swift and tests preserve bytes',!mismatches.length,{files:Object.keys(before.hashes).length,mismatches});
for(const [path,original] of Object.entries(before.originals)){
 let current=await read(path);
 if(path.endsWith('tokens.json')){
  const value=JSON.parse(current);delete value.appleVercel;
  check('Existing token namespaces are unchanged',isDeepStrictEqual(value,JSON.parse(original)));continue;
 }
 if(path.endsWith('App.tsx'))current=current.replace("import './designSystem/appleVercel.css'\n",'').replace("minimalChrome={isV3Screen||screen==='home'}",'minimalChrome={isV3Screen}');
 else current=current.replaceAll(' av-screen av-studio-empty','').replaceAll(' av-screen av-studio','').replaceAll(' av-screen av-home','');
 check(path+' contains only the declared presentation changes',current===original);
}
const git=args=>execFileSync('git',args,{cwd:root,encoding:'utf8'}).trim();
check('Published HEAD stays unchanged',git(['rev-parse','HEAD'])==='9490d02071aa3be0add4821717f7b0b515bffa38');
check('No new commits',git(['rev-list','--count','HEAD'])==='50');
function luminance(hex){const values=hex.match(/[0-9a-f]{2}/gi).map(v=>parseInt(v,16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4);return values[0]*.2126+values[1]*.7152+values[2]*.0722}
function contrast(name,foreground,background,minimum=4.5){const a=luminance(foreground),b=luminance(background),ratio=(Math.max(a,b)+.05)/(Math.min(a,b)+.05);report.contrast.push({name,foreground,background,ratio:Number(ratio.toFixed(2)),minimum});check(name+' contrast',ratio>=minimum)}
const {appleVercel:tokens}=JSON.parse(await read('design/tokens.json'));
for(const mode of ['light','dark']){
 const colors=tokens.colors[mode];
 for(const role of ['text','secondary','muted','accent'])contrast(mode+' '+role,colors[role],colors.surface);
 contrast(mode+' selected navigation',colors.accent,colors.accentSoft);
}
contrast('Canvas caption',tokens.canvas.secondary,tokens.canvas.background);
contrast('Canvas selected wave',tokens.canvas.wave,tokens.canvas.background,3);
contrast('Primary action', '#FFFFFF',tokens.action);
const bright='#'+tokens.action.slice(1).match(/../g).map(v=>Math.round(parseInt(v,16)*.9+255*.1).toString(16).padStart(2,'0')).join('');
contrast('Primary action lightest gradient stop','#FFFFFF',bright);
report.passed=report.checks.filter(row=>row.passed).length;report.failed=report.checks.filter(row=>!row.passed);
await writeFile(join(root,'design/review/apple-vercel-scope.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({checks:report.checks.length,passed:report.passed,failed:report.failed,contrast:report.contrast}));
if(report.failed.length)process.exitCode=1;
