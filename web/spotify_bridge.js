/* Spotify Web Playback SDK + Authorization Code PKCE. No client secret. */
(() => {
  const clientId = '1bdc621fcaa74a21a2c2f90b5b5f0cbc';
  const redirectUri = location.origin + location.pathname;
  const prefix = 'droplyric.spotify.';
  let player, deviceId, refreshPromise, connectPromise;
  let playback = null, sampledAt = 0, error = '';
  const read = key => sessionStorage.getItem(prefix + key);
  const write = (key, value) => sessionStorage.setItem(prefix + key, value);
  const clear = () => ['access', 'refresh', 'expires', 'verifier', 'state'].forEach(k => sessionStorage.removeItem(prefix + k));
  const random = () => Array.from(crypto.getRandomValues(new Uint8Array(32)), n => n.toString(16).padStart(2, '0')).join('');
  async function tokens(params) {
    const response = await fetch('https://accounts.spotify.com/api/token', {
      method: 'POST', headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: new URLSearchParams({client_id: clientId, ...params}),
    });
    if (!response.ok) {
      if (response.status === 400 || response.status === 401) clear();
      throw Error('Sessão Spotify expirada. Conecte sua conta novamente.');
    }
    const data = await response.json();
    write('access', data.access_token);
    if (data.refresh_token) write('refresh', data.refresh_token);
    write('expires', Date.now() + data.expires_in * 1000);
    return data.access_token;
  }
  async function token() {
    if (read('access') && Number(read('expires')) > Date.now() + 60000) return read('access');
    if (!read('refresh')) throw Error('Conecte sua conta Spotify.');
    if (!refreshPromise) refreshPromise = tokens({grant_type: 'refresh_token', refresh_token: read('refresh')}).finally(() => refreshPromise = null);
    return refreshPromise;
  }
  const initialized = (async () => {
    const query = new URLSearchParams(location.search);
    if (!query.has('code') && !query.has('error')) return;
    history.replaceState(null, '', location.pathname + location.hash);
    try {
      if (!read('state') || query.get('state') !== read('state')) throw Error('Retorno do login inválido. Tente conectar novamente.');
      if (query.has('error')) throw Error('Login Spotify cancelado.');
      const verifier = read('verifier');
      if (!verifier) throw Error('Login expirado. Tente novamente.');
      await tokens({grant_type: 'authorization_code', code: query.get('code'), redirect_uri: redirectUri, code_verifier: verifier});
    } catch (e) { error = e.message; }
    finally { sessionStorage.removeItem(prefix + 'state'); sessionStorage.removeItem(prefix + 'verifier'); }
  })();
  async function api(path, method = 'GET', body, retry = true) {
    const response = await fetch('https://api.spotify.com/v1/' + path, {
      method, headers: {Authorization: 'Bearer ' + await token(), 'Content-Type': 'application/json'},
      ...(body === undefined ? {} : {body: JSON.stringify(body)}),
    });
    if (response.status === 401 && retry) { write('expires', 0); return api(path, method, body, false); }
    if (!response.ok) {
      const messages = {403: 'Spotify recusou o acesso. Confira Premium e Users Management no painel do aplicativo.',
        404: 'Player Spotify indisponível. Reconecte e tente novamente.',
        429: 'Limite do Spotify atingido. Aguarde antes de tentar novamente.'};
      throw Error(messages[response.status] || `Erro Spotify (${response.status}). Tente novamente.`);
    }
    return response.status === 204 ? null : response.json();
  }
  function loadSdk() {
    if (window.Spotify) return Promise.resolve();
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(Error('Não foi possível carregar o player Spotify.')), 15000);
      window.onSpotifyWebPlaybackSDKReady = () => { clearTimeout(timer); resolve(); };
      const script = document.createElement('script'); script.src = 'https://sdk.scdn.co/spotify-player.js';
      script.onerror = () => { clearTimeout(timer); reject(Error('Falha de rede ao carregar Spotify.')); };
      document.head.appendChild(script);
    });
  }
  async function connect() {
    if (deviceId && player) return;
    if (connectPromise) return connectPromise;
    connectPromise = (async () => {
      await token(); await loadSdk();
      if (player) player.disconnect();
      await new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(Error('Spotify demorou para conectar. Tente novamente.')), 20000);
        player = new Spotify.Player({name: 'Droplyric', volume: 0.7,
          getOAuthToken: callback => token().then(callback).catch(e => { error = e.message; })});
        player.addListener('ready', state => { deviceId = state.device_id; clearTimeout(timer); resolve(); });
        player.addListener('not_ready', () => { deviceId = null; playback = null; });
        player.addListener('player_state_changed', state => { playback = state; sampledAt = performance.now(); });
        for (const event of ['initialization_error', 'authentication_error', 'account_error', 'playback_error']) {
          player.addListener(event, () => {
            error = event === 'account_error' ? 'A reprodução exige Spotify Premium.' : 'Falha no player Spotify. Reconecte sua conta.';
            clearTimeout(timer); reject(Error(error));
          });
        }
        player.connect().then(ok => { if (!ok) { clearTimeout(timer); reject(Error('Não foi possível conectar ao Spotify.')); } }).catch(reject);
      });
    })().finally(() => connectPromise = null);
    return connectPromise;
  }
  window.droplyricSpotifyState = () => JSON.stringify({
    authenticated: !!read('refresh'), ready: !!deviceId, error,
    uri: playback?.track_window?.current_track?.uri || '',
    paused: playback?.paused ?? true,
    position: playback ? Math.min(playback.duration, playback.position + (playback.paused ? 0 : performance.now() - sampledAt)) : 0,
    duration: playback?.duration || 0,
  });
  window.droplyricSpotifyCall = async (action, argument = '') => {
    try {
      await initialized;
      if (action !== 'initialize') error = '';
      if (action === 'initialize') return JSON.stringify({});
      if (action === 'login') {
        const verifier = random(), state = random();
        write('verifier', verifier); write('state', state);
        const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
        const challenge = btoa(String.fromCharCode(...new Uint8Array(digest))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
        location.assign('https://accounts.spotify.com/authorize?' + new URLSearchParams({
          client_id: clientId, response_type: 'code', redirect_uri: redirectUri, state,
          code_challenge_method: 'S256', code_challenge: challenge,
          scope: 'streaming user-read-email user-read-private user-read-playback-state user-modify-playback-state',
        }));
      } else if (action === 'logout') {
        player?.disconnect(); player = null; deviceId = null; playback = null; clear();
      } else if (action === 'search') {
        return JSON.stringify(await api('search?' + new URLSearchParams({q: argument, type: 'track', limit: '10'})));
      } else if (action === 'track') {
        if (!/^[a-zA-Z0-9]{22}$/.test(argument)) throw Error('Faixa Spotify inválida.');
        return JSON.stringify(await api('tracks/' + argument));
      } else if (action === 'play') {
        if (!/^spotify:track:[a-zA-Z0-9]{22}$/.test(argument)) throw Error('Faixa Spotify inválida.');
        await connect(); await player.activateElement();
        if (playback?.track_window.current_track.uri === argument) await player.resume();
        else await api('me/player/play?device_id=' + encodeURIComponent(deviceId), 'PUT', {uris: [argument]});
      } else if (action === 'pause') { if (player) await player.pause(); }
      else if (action === 'seek') {
        if (player && playback) { await player.seek(Math.max(0, Math.min(playback.duration, Number(argument)))); playback = await player.getCurrentState(); sampledAt = performance.now(); }
      }
      return '{}';
    } catch (e) { error = e.message || 'Falha ao conectar ao Spotify.'; throw Error(error); }
  };
})();
