// Create a local, immutable backup before the authorized source-import batch.
// Never changes source files, history, dates, remote state or credentials.
import {execFileSync} from 'node:child_process';
import {readFile,writeFile,mkdir,copyFile,stat} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve,join,dirname} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const git=(...args)=>execFileSync('git',args,{cwd:root,encoding:'utf8',windowsHide:true});
const target=join(root,'.git/ringify-day2-20261104');
await mkdir(target); // Refuse to overwrite an existing backup.
const head=git('rev-parse','HEAD').trim();
const staged=git('diff','--cached','--name-only');
if(staged.trim())throw Error('Existing staged work must be preserved and reviewed before batching.');
const files=[...new Set([...git('ls-files','-z').split('\0'),...git('ls-files','--others','--exclude-standard','-z').split('\0')].filter(Boolean))].sort();
const hashes={},sizes={},suspects=[];
const signatures=[['private-key',/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/],['github-token',/\b(?:gh[pousr]_[a-zA-Z0-9]{30,}|github_pat_[a-zA-Z0-9_]{40,})\b/],['aws-key',/\bAKIA[A-Z0-9]{16}\b/]];
for(const file of files){
 if(file.startsWith('../')||file.includes('\\'))throw Error('Unexpected Git path');
 const source=join(root,file),bytes=await readFile(source);
 hashes[file]=createHash('sha256').update(bytes).digest('hex');sizes[file]=bytes.length;
 if(bytes.length>=50*1024*1024)throw Error(`Oversize candidate: ${file}`);
 if(/\.(swift|[cm]?js|tsx?|json|md|ya?ml|sh|plist|strings|css|html|svg)$/.test(file)){
  const text=bytes.toString('utf8');for(const [rule,pattern]of signatures)if(pattern.test(text))suspects.push({file,rule});
 }
 const copy=join(target,'working-tree',file);await mkdir(dirname(copy),{recursive:true});await copyFile(source,copy);
}
const bundle=join(target,'before.bundle');git('bundle','create',bundle,'--all');git('bundle','verify',bundle);
await writeFile(join(target,'before.json'),JSON.stringify({head,count:Number(git('rev-list','--count','HEAD')),branch:git('branch','--show-current').trim(),files:hashes,sizes,status:git('status','--porcelain=v1','--untracked-files=all'),suspects},null,2)+'\n');
console.log(JSON.stringify({head,files:files.length,bytes:Object.values(sizes).reduce((a,b)=>a+b,0),suspects,backup:'.git/ringify-day2-20261104'}));
if(suspects.length)process.exitCode=1;
