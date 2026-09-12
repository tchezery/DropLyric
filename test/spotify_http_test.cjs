const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('web/spotify_bridge.js', 'utf8');
function setup(statuses, expired = false) {
  const data = new Map(Object.entries({access: 'test-access', refresh: 'test-refresh', expires: expired ? '0' : String(Date.now() + 3600000)}).map(([k,v]) => ['droplyric.spotify.' + k,v]));
  const requests = [];
  const context = {window: {}, location: {origin:'http://127.0.0.1:8080', pathname:'/', search:''}, URLSearchParams, Date, performance,
    sessionStorage: {getItem:k=>data.get(k), setItem:(k,v)=>data.set(k,v), removeItem:k=>data.delete(k)},
    setTimeout: callback=>{callback();return 1;},
    fetch: async (url, options)=>{requests.push({url,options}); const status=statuses.shift(); assert.ok(status); return {status,ok:status===200,json:async()=>({tracks:{items:[]}})};}};
  vm.runInNewContext(source, context);
  return {call:context.window.droplyricSpotifyCall,requests,data};
}
test('search recovers after temporary 502',async()=>{const s=setup([502,200]); assert.deepEqual(JSON.parse(await s.call('search','test')), {tracks:{items:[]}});assert.equal(s.requests.length,2);});
test('persistent 502 is bounded and retains session',async()=>{const s=setup([502,502,502]);await assert.rejects(s.call('search','test'), /temporariamente indisponível \(HTTP 502\)/);assert.equal(s.requests.length,3);assert.equal(s.data.get('droplyric.spotify.refresh'),'test-refresh');});
test('403 and 429 are not retried',async()=>{for(const status of [403,429]){const s=setup([status]);await assert.rejects(s.call('search','test'));assert.equal(s.requests.length,1);}});
test('token 502 is not reported as expired or replayed',async()=>{const s=setup([502],true);await assert.rejects(s.call('search','test'),/temporariamente indisponível \(HTTP 502\)/);assert.equal(s.requests.length,1);assert.equal(s.data.get('droplyric.spotify.refresh'),'test-refresh');});
