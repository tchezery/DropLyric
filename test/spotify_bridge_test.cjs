const {readFileSync} = require('node:fs');
const {runInNewContext} = require('node:vm');
const {webcrypto} = require('node:crypto');
const assert = require('node:assert/strict');
const source = readFileSync(require('node:path').join(__dirname, '../web/spotify_bridge.js'),'utf8');
function fixture(query='', stored={}) {
 const store=new Map(Object.entries(stored)), calls=[];
 const env={URLSearchParams, Uint8Array, TextEncoder, crypto:webcrypto, btoa:s=>Buffer.from(s,'binary').toString('base64'),
  sessionStorage:{getItem:k=>store.get(k)||null,setItem:(k,v)=>store.set(k,String(v)),removeItem:k=>store.delete(k)},
  location:{origin:'http://127.0.0.1:8080',pathname:'/',search:query,hash:'',assign:url=>calls.push(url)},
  history:{replaceState(){}},performance:{now:()=>0},setTimeout,clearTimeout,
  fetch: async (url,options)=>{ calls.push({url,options});return {ok:true,status:200,json:async()=>({access_token:'test',refresh_token:'refresh',expires_in:3600})}; },
 };env.window=env;runInNewContext(source,env);return {env,calls,store};
}
(async()=>{
 const a=fixture();await a.env.droplyricSpotifyCall('login');
 const url=new URL(a.calls[0]);assert.equal(url.searchParams.get('code_challenge_method'),'S256');
 assert.equal(url.searchParams.get('redirect_uri'),'http://127.0.0.1:8080/');
 assert.ok(url.searchParams.get('state'));assert.ok(!url.searchParams.has('client_secret'));
 const b=fixture('?code=untrusted&state=wrong',{'droplyric.spotify.state':'expected','droplyric.spotify.verifier':'verifier'});
 await b.env.droplyricSpotifyCall('initialize');assert.equal(b.calls.length,0);assert.match(JSON.parse(b.env.droplyricSpotifyState()).error,/inválido/);
 const c=fixture('?code=valid&state=expected',{'droplyric.spotify.state':'expected','droplyric.spotify.verifier':'verifier'});
 await c.env.droplyricSpotifyCall('initialize');assert.equal(c.calls.length,1);
 assert.equal(c.calls[0].options.body.get('code_verifier'),'verifier');assert.equal(JSON.parse(c.env.droplyricSpotifyState()).authenticated,true);
 await c.env.droplyricSpotifyCall('logout');assert.equal(JSON.parse(c.env.droplyricSpotifyState()).authenticated,false);
 console.log('PASS: PKCE redirect, random state, invalid callback rejected, token exchange, logout.');
})().catch(e=>{console.error(e);process.exitCode=1});
