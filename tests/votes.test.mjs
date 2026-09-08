import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import ts from 'typescript';
const moduleURL = source => 'data:text/javascript;base64,' + Buffer.from(ts.transpileModule(source, {compilerOptions:{module:ts.ModuleKind.ESNext,target:ts.ScriptTarget.ES2022}}).outputText).toString('base64');
const dataURL=moduleURL(await readFile(new URL('../data/restaurants.ts',import.meta.url),'utf8'));
const {ids,restaurants}=await import(dataURL);
const {validRanking,leaderboard}=await import(moduleURL((await readFile(new URL('../lib/votes.ts',import.meta.url),'utf8')).replace("'../data/restaurants'",JSON.stringify(dataURL))));
const vote=ranking=>({id:'test',name:'Test',ranking,created_at:'',updated_at:''});
test('all permutations of six IDs are valid; incomplete, duplicate and foreign IDs fail',()=>{
 assert.equal(ids.length,6);assert.equal(new Set(ids).size,6);
 function permutations(rest,prefix=[]){if(!rest.length){assert.ok(validRanking(prefix));return;}rest.forEach((id,i)=>permutations(rest.filter((_,j)=>i!==j),[...prefix,id]));}
 permutations(ids);
 for(const invalid of [null,{},ids.slice(0,5),[...ids,ids[0]],[...ids.slice(0,5),ids[0]],[...ids.slice(0,5),'unknown']])assert.equal(validRanking(invalid),false);
});
test('one ballot awards 6–5–4–3–2–1; reverse ballots tie at seven; invalid legacy votes add nothing',()=>{
 const scores=leaderboard([vote(ids)]);ids.forEach((id,i)=>assert.equal(scores.find(r=>r.id===id).points,6-i));
 const tied=leaderboard([vote(ids),vote([...ids].reverse()),vote(ids.slice(0,5))]);
 tied.forEach(r=>{assert.equal(r.points,7);assert.equal(r.average,3.5)});
 assert.equal(scores.reduce((sum,r)=>sum+r.points,0),21);
 leaderboard([]).forEach(r=>assert.equal(r.points,0));
});
test('every record has menu sections and images; Ivy has all five requested groups',()=>{
 restaurants.forEach(r=>{assert.ok(Array.isArray(r.menuSections));assert.ok(r.images.length>0)});
 const ivy=restaurants.find(r=>r.id==='ivy');assert.deepEqual(ivy.menuSections.map(s=>s.title),['For the Table','Starters','Mains','Grill','Sides']);
 assert.equal(ivy.menuUrl,'https://ivycollection.com/restaurants-near-me/the-ivy-north-west/the-ivy-manchester/a-la-carte-menu/');
});
