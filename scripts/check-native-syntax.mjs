// Syntax only: no linking, Apple SDK type checking, simulator or app execution.
import {spawnSync} from 'node:child_process';
import {readFile,readdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join,resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const folders=['ios/Ringify','ios/RingifyTests','ios/RingifyUITests','packages/RingifyCore/Sources','packages/RingifyCore/Tests'];
async function swiftFiles(folder){
 const entries=await readdir(join(root,folder),{withFileTypes:true});
 return (await Promise.all(entries.map(entry=>entry.isDirectory()?swiftFiles(folder+'/'+entry.name):
  entry.isFile()&&entry.name.endsWith('.swift')?[folder+'/'+entry.name]:[]))).flat();
}
const files=(await Promise.all(folders.map(swiftFiles))).flat().sort();
const hashes={};for(const file of files)hashes[file]=createHash('sha256').update(await readFile(join(root,file))).digest('hex');
const compiler=process.env.RINGIFY_SWIFTC||(process.platform==='win32'?'swiftc.exe':'swiftc');
const args=['-frontend','-parse',...files];
const result=spawnSync(compiler,args,{cwd:root,encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:1024*1024});
const report={
 scope:'Real Swift parser only. Does not validate Apple SDK APIs/types, linking, Swift concurrency semantics, UI layout or test execution.',
 compiler,args,exitCode:result.status,signal:result.signal,error:result.error?.message??null,
 passed:result.status===0&&!result.error,
 files:hashes,stdout:result.stdout??'',stderr:result.stderr??'',
 nativeFeatureStatus:'IMPLEMENTED_NOT_TESTED',nativeBuild:'NOT_TESTED',nativeTests:'NOT_TESTED'
};
await writeFile(join(root,'design/review/native-syntax.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({parserPassed:report.passed,files:files.length,exitCode:report.exitCode,nativeBuild:report.nativeBuild,nativeTests:report.nativeTests}));
if(!report.passed){process.stderr.write(report.stderr||report.error||'Swift parser did not complete.');process.exitCode=1}
