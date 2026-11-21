import './style.css';
import { clamp, distance, inRange, newEncounter, damageEnemy, dodgeDirection } from './combat.js';
import { defaultSave, loadSave, writeSave, recordVictory } from './save.js';

const app = document.querySelector('#app');
app.innerHTML = `
<section class="screen loading" id="loading" aria-live="polite">
  <div class="loading-inner"><div class="brand"><div class="brand-mark"><span>✦</span></div>SCARLET VEIL</div><div class="loading-copy"><div class="eyebrow">SYSTEM INITIALIZATION</div><h1>THE NIGHT<br>AWAITS<span>.</span></h1><p id="loading-message">Preparing mission assets</p><div class="loading-track"><i id="loading-bar"></i></div><div class="loading-meta"><span id="loading-progress">0 / 4 ASSETS</span><span>SCARLET VEIL / 01</span></div><button class="loading-retry hidden" id="loading-retry">RETRY LOADING ↗</button></div><div class="loading-bottom">ORIGINAL ACTION RPG &nbsp; / &nbsp; OFFLINE BUILD</div></div>
</section>
<section class="screen home hidden" id="home">
  <header class="topbar"><div class="brand"><div class="brand-mark"><span>✦</span></div>SCARLET VEIL</div><div class="top-right"><span>THE CITY NEVER SLEEPS</span><span class="line"></span><button class="menu-icon" id="settings-open" aria-label="Settings">⚙</button></div></header>
  <main class="home-content"><div class="eyebrow">The city never sleeps</div><h1>Scarlet<br><span>Veil.</span></h1><div class="subheading">A BLADE AGAINST THE DARK</div><div class="rule"></div><p class="description">When the lights go out, the hunt begins. Step into the storm and carve a path through the unknown.</p><div class="mission"><div class="mission-icon">⌁</div><div><strong>OPERATION: NIGHTFALL</strong><small>COMBAT TRIAL &nbsp; / &nbsp; ROOFTOP 01</small></div></div><button class="deploy" id="start"><strong>SELECT OPERATION</strong><span>↗</span></button><div class="home-stats" id="home-stats">FIRST DEPLOYMENT &nbsp; / &nbsp; GOOD LUCK, AGENT</div></main>
  <footer class="home-footer"><div class="footer-label"><div class="index">01</div><div><strong>REI KUROSAWA</strong><br>THE CRIMSON BLADE</div></div><div class="prototype">OFFLINE COMBAT SLICE<br>SCARLET VEIL / 0.2</div></footer>
  <div class="menu-modal hidden" id="briefing" role="dialog" aria-modal="true" aria-labelledby="briefing-title"><div class="menu-card"><div class="card-top"><span>MISSION BRIEFING / 01</span><button class="close-btn" id="brief-close" aria-label="Close briefing">×</button></div><div class="eyebrow">Combat operation</div><h2 id="briefing-title">NIGHTFALL<span>.</span></h2><p>Hostile units have occupied the rooftop. Clear the area and make it out in one piece.</p><div class="brief-details"><div><small>OBJECTIVE</small><strong>ELIMINATE 6 HOSTILES</strong></div><div><small>ACTIVE AGENT</small><strong>REI KUROSAWA</strong></div></div><div class="tip-line">MOVE <b>·</b> ATTACK <b>·</b> DODGE RED WARNINGS <b>·</b> CHARGE YOUR SKILL</div><button class="deploy" id="deploy"><strong>DEPLOY TO ROOFTOP</strong><span>↗</span></button></div></div>
  <div class="menu-modal hidden" id="settings" role="dialog" aria-modal="true" aria-labelledby="settings-title"><div class="menu-card settings-card"><div class="card-top"><span>PERSONAL PREFERENCES</span><button class="close-btn" id="settings-close" aria-label="Close settings">×</button></div><div class="eyebrow">Your experience</div><h2 id="settings-title">SETTINGS<span>.</span></h2><p>Settings are stored on this device.</p><button class="setting-row" id="setting-audio" aria-pressed="true"><span><strong>AUDIO</strong><small>Music and combat effects</small></span><b>ON</b></button><button class="setting-row" id="setting-motion" aria-pressed="false"><span><strong>REDUCE MOTION</strong><small>Disable impact camera shake</small></span><b>OFF</b></button></div></div>
</section>
<section class="screen game hidden" id="game" aria-label="Combat encounter">
  <div class="arena-bg"></div><canvas id="canvas" aria-label="Rooftop combat arena"></canvas>
  <div class="hud"><div class="hud-top"><div class="objective"><div class="diamond"><span>✦</span></div><div><small>OPERATION: NIGHTFALL</small><strong>Clear the rooftop</strong></div></div><div class="encounter-count"><small>HOSTILES REMAINING</small><span id="remaining">06</span> / 06</div><div class="top-controls"><button class="icon-btn" id="sound" aria-label="Toggle sound" title="Toggle sound">♫</button><button class="icon-btn" id="pause" aria-label="Pause" title="Pause">Ⅱ</button></div></div>
    <div class="hint" id="hint">Move to engage · Chain attacks · Dodge the red warning</div>
    <div class="hud-bottom"><div class="stick" data-stick aria-label="Movement joystick"><div class="stick-knob"></div><div class="stick-label">MOVE</div></div><div class="player-info"><small>ACTIVE AGENT &nbsp; / &nbsp; 01</small><strong>REI KUROSAWA</strong><div class="bars"><i id="health" style="width:100%"></i></div><div class="bars energy"><i id="energy" style="width:0%"></i></div></div><div class="actions"><div class="action-wrap"><button class="action skill disabled" id="skill" aria-label="Use crimson skill">✧</button><small>SKILL · E</small></div><div class="action-wrap"><button class="action" id="dodge" aria-label="Dodge">➜</button><small>DODGE · SPACE</small></div><div class="action-wrap"><button class="action attack" id="attack" aria-label="Attack">⚔</button><small>ATTACK · J</small></div></div></div>
  </div><div class="overlay hidden" id="overlay"><div class="overlay-card"><div class="eyebrow" style="justify-content:center" id="overlay-kicker">COMBAT TRIAL</div><h2 id="overlay-title">Paused</h2><p id="overlay-text"></p><button class="deploy" id="overlay-action"><strong>RESUME</strong><span>↗</span></button><button class="secondary" id="back">RETURN TO TITLE</button></div></div>
<div class="orientation-notice"><div><span>↻</span><strong>ROTATE YOUR DEVICE</strong><p>Combat is designed for landscape. Rotate to continue.</p></div></div></section>`;
const $ = id => document.getElementById(id);
const canvas = $('canvas'), ctx = canvas.getContext('2d', { alpha: true });
const fighter = new Image(); fighter.src = `${import.meta.env.BASE_URL}art/fighter.png`;
const sentinel = new Image(); sentinel.src = `${import.meta.env.BASE_URL}art/sentinel.png`;
let storage; try { storage = window.localStorage; } catch { storage = null; }
let save = storage ? loadSave(storage) : defaultSave();
let state, last = 0, active = false, paused = false, muted = save.muted, audio, musicTimer, musicStep = 0, footTimer = 0, frameId = 0;
const persist = () => { if (storage) writeSave(storage, save); };
const keys = new Set(), stick = { x: 0, y: 0, pointer: null };
const W = 1000, H = 600;

function tone(freq, duration, type = 'sine', volume = .035, delay = 0, endFreq = freq) {
  if (!audio || muted || audio.state !== 'running') return;
  const t = audio.currentTime + delay, osc = audio.createOscillator(), gain = audio.createGain();
  osc.type = type; osc.frequency.setValueAtTime(freq,t); osc.frequency.exponentialRampToValueAtTime(Math.max(1,endFreq), t + duration);
  gain.gain.setValueAtTime(.0001,t); gain.gain.exponentialRampToValueAtTime(volume,t+.015); gain.gain.exponentialRampToValueAtTime(.0001,t+duration);
  osc.connect(gain); gain.connect(audio.destination); osc.start(t); osc.stop(t+duration+.02);
}
function startAudio() {
  try {
    audio ||= new (window.AudioContext || window.webkitAudioContext)();
    if (audio.state === 'suspended') audio.resume();
    if (!musicTimer) musicTimer = setInterval(() => {
      if (!active || paused || muted || document.hidden) return;
      const melody = [220, 0, 329.63, 293.66, 261.63, 0, 196, 220, 174.61, 0, 261.63, 220, 196, 0, 164.81, 196];
      const n = melody[musicStep++ % melody.length];
      if (n) { tone(n,.52,'triangle',.012); tone(n*2,.3,'sine',.006,.02); }
      if (musicStep % 4 === 1) tone(n/2,.9,'sine',.018);
    }, 360);
  } catch { /* Audio is optional. */ }
}
function effect(kind) {
  if (kind === 'swing') { tone(440,.13,'sawtooth',.018,0,110); tone(820,.09,'triangle',.014,0,300); }
  if (kind === 'hit') { tone(120,.16,'sawtooth',.035,0,45); tone(660,.1,'square',.012,0,160); }
  if (kind === 'dodge') tone(260,.2,'triangle',.025,0,650);
  if (kind === 'hurt') tone(170,.24,'sawtooth',.03,0,65);
  if (kind === 'step') tone(75,.06,'triangle',.012,0,50);
  if (kind === 'skill') { tone(170,.4,'sawtooth',.04,0,700); tone(440,.5,'triangle',.025,.08,880); }
}
function refreshMenu() {
  $('home-stats').textContent = save.wins ? `OPERATIONS CLEARED  ${save.wins}   /   BEST  ${Math.floor(save.bestTime)}s` : 'FIRST DEPLOYMENT  /  GOOD LUCK, AGENT';
  $('setting-audio').setAttribute('aria-pressed', String(!muted)); $('setting-audio').querySelector('b').textContent = muted ? 'OFF' : 'ON';
  $('setting-motion').setAttribute('aria-pressed', String(save.reducedMotion)); $('setting-motion').querySelector('b').textContent = save.reducedMotion ? 'ON' : 'OFF';
  $('sound').textContent = muted ? '×' : '♫'; $('sound').setAttribute('aria-label', muted ? 'Enable sound' : 'Mute sound');
}
function toggleAudio() { muted = !muted; save.muted = muted; persist(); refreshMenu(); if (!muted && active) startAudio(); }
$('settings-open').addEventListener('click', () => { refreshMenu(); $('settings').classList.remove('hidden'); $('settings-close').focus(); });
$('settings-close').addEventListener('click', () => { $('settings').classList.add('hidden'); $('settings-open').focus(); });
$('setting-audio').addEventListener('click', toggleAudio);
$('setting-motion').addEventListener('click', () => { save.reducedMotion = !save.reducedMotion; persist(); refreshMenu(); });
$('start').addEventListener('click', () => { $('briefing').classList.remove('hidden'); $('deploy').focus(); });
$('brief-close').addEventListener('click', () => { $('briefing').classList.add('hidden'); $('start').focus(); });
$('deploy').addEventListener('click', () => { $('briefing').classList.add('hidden'); start(); });
async function loadAssets() {
  const assets = ['art/veil-keyart.png', 'art/arena.png', 'art/fighter.png', 'art/sentinel.png'];
  let loaded = 0; $('loading-retry').classList.add('hidden'); $('loading-message').textContent = 'Preparing mission assets';
  $('loading-bar').style.width = '0%'; $('loading-progress').textContent = '0 / 4 ASSETS';
  const results = await Promise.all(assets.map(path => new Promise(resolve => {
    const image = new Image(); let settled = false;
    const finish = ok => { if (settled) return; settled = true; clearTimeout(timeout); image.onload = image.onerror = null; if (ok) { loaded++; $('loading-bar').style.width = `${loaded / assets.length * 100}%`; $('loading-progress').textContent = `${loaded} / ${assets.length} ASSETS`; } resolve(ok); };
    const timeout = setTimeout(() => finish(false), 12000);
    image.onload = () => finish(true); image.onerror = () => finish(false); image.src = `${import.meta.env.BASE_URL}${path}`;
  })));
  if (results.every(Boolean)) { refreshMenu(); $('loading').classList.add('hidden'); $('home').classList.remove('hidden'); }
  else { $('loading-message').textContent = 'Unable to load game assets. Please try again.'; $('loading-retry').classList.remove('hidden'); }
}
$('loading-retry').addEventListener('click', loadAssets);
loadAssets();
function resize() { const dpr = Math.min(window.devicePixelRatio || 1, 1.5); canvas.width = Math.round(innerWidth*dpr); canvas.height = Math.round(innerHeight*dpr); }
window.addEventListener('resize', resize); resize();
const portrait = window.matchMedia('(max-width: 700px) and (orientation: portrait)');
portrait.addEventListener('change', e => { if (e.matches && active && !paused) pause(); });
function start() { cancelAnimationFrame(frameId); resetInput(); state = newEncounter(); active = true; paused = false; last = 0; keys.clear(); stick.x=stick.y=0; $('home').classList.add('hidden'); $('game').classList.remove('hidden'); $('overlay').classList.add('hidden'); $('hint').classList.remove('hidden'); startAudio(); updateHud(); frameId = requestAnimationFrame(loop); if (portrait.matches) pause(); }
function endOverlay(title, text, button) { paused = true; cancelAnimationFrame(frameId); resetInput(); $('overlay-title').textContent = title; $('overlay-text').textContent = text; $('overlay-action').querySelector('strong').textContent = button; $('overlay').classList.remove('hidden'); }
function pause() { if (!active || paused) return; endOverlay('Paused', 'Take a breath. The rooftop can wait.', 'RESUME'); }
function resume() { if (!active || state.status !== 'playing') return; paused = false; last = 0; $('overlay').classList.add('hidden'); startAudio(); cancelAnimationFrame(frameId); frameId = requestAnimationFrame(loop); }
$('pause').addEventListener('click', pause);
$('sound').addEventListener('click', toggleAudio);
$('overlay-action').addEventListener('click', () => state.status === 'playing' ? resume() : start());
$('back').addEventListener('click', () => { active = false; paused = false; cancelAnimationFrame(frameId); resetInput(); refreshMenu(); $('overlay').classList.add('hidden'); $('game').classList.add('hidden'); $('home').classList.remove('hidden'); });
document.addEventListener('visibilitychange', () => { if (document.hidden && active && !paused) pause(); });

function burst(x,y,color,count=10) { for(let i=0;i<count && state.particles.length<100;i++){ const a=Math.random()*Math.PI*2, v=35+Math.random()*160; state.particles.push({x,y,vx:Math.cos(a)*v,vy:Math.sin(a)*v,life:.25+Math.random()*.35,max:.6,color}); } }
function label(x,y,text,color='#fff') { state.messages.push({x,y,text,color,life:.7}); if (state.messages.length>20) state.messages.shift(); }
function attack() {
  if (!active || paused || state.status !== 'playing') return;
  const p=state.player; if (p.attackCooldown>0 || p.dodgeTime>0) return;
  p.attackCooldown=.3; p.swing=.23; p.combo=(p.combo%3)+1; effect('swing');
  const targets=state.enemies.filter(e=>e.hp>0 && inRange(p,e,155)).sort((a,b)=>distance(p,a)-distance(p,b));
  if(targets.length) { const e=targets[0]; p.facing=e.x>=p.x?1:-1; damageEnemy(state,e,1); p.energy=clamp(p.energy+20,0,100); state.shake=4; burst(e.x,e.y-35,'#ff5765',12); label(e.x,e.y-95,p.combo===3?'BREAK':'HIT'); effect('hit'); }
  updateHud(); checkEnd();
}
function dodge() {
  if (!active || paused || state.status !== 'playing') return;
  const p=state.player; if(p.dodgeCooldown>0) return;
  const dir=dodgeDirection(movement(),p.facing); p.dx=dir.x; p.dy=dir.y;
  p.dodgeTime=.23; p.invulnerable=.32; p.dodgeCooldown=1.1; effect('dodge'); burst(p.x,p.y,'#b7d6ea',7);
}
function skill() {
  if (!active || paused || state.status !== 'playing') return;
  const p=state.player; if(p.energy<100) { label(p.x,p.y-130,'CHARGE WITH ATTACKS','#d3dbe0'); return; }
  p.energy=0; p.swing=.45; p.invulnerable=.45; state.shake=8; effect('skill'); burst(p.x,p.y-20,'#ff3c52',35);
  state.enemies.forEach(e=>{if(e.hp>0 && inRange(p,e,230)){damageEnemy(state,e,3);burst(e.x,e.y-30,'#ffb3aa',15);label(e.x,e.y-100,'CRIMSON');}});
  updateHud(); checkEnd();
}
function movement() { let x=(keys.has('d')||keys.has('arrowright')?1:0)-(keys.has('a')||keys.has('arrowleft')?1:0)+stick.x, y=(keys.has('s')||keys.has('arrowdown')?1:0)-(keys.has('w')||keys.has('arrowup')?1:0)+stick.y; const n=Math.hypot(x,y); if(n>1){x/=n;y/=n} return {x,y}; }
window.addEventListener('keydown', e=>{const k=e.key.toLowerCase(); if([' ','arrowup','arrowdown','arrowleft','arrowright'].includes(k))e.preventDefault(); keys.add(k); if(e.repeat)return; if(k==='j'||k==='enter')attack(); if(k===' '||k==='k')dodge(); if(k==='e')skill(); if(k==='escape') paused?resume():pause(); });
window.addEventListener('keyup', e=>keys.delete(e.key.toLowerCase()));
for(const [id,fn] of [['attack',attack],['dodge',dodge],['skill',skill]]) $(id).addEventListener('pointerdown',e=>{e.preventDefault();fn()});
const stickEl=document.querySelector('[data-stick]'), knob=stickEl.querySelector('.stick-knob');
function moveStick(e){const r=stickEl.getBoundingClientRect(), radius=r.width*.37; let x=(e.clientX-(r.left+r.width/2))/radius,y=(e.clientY-(r.top+r.height/2))/radius; const n=Math.hypot(x,y);if(n>1){x/=n;y/=n} stick.x=x;stick.y=y;knob.style.transform=`translate(${x*radius}px,${y*radius}px)`;}
stickEl.addEventListener('pointerdown',e=>{e.preventDefault();stick.pointer=e.pointerId;stickEl.setPointerCapture(e.pointerId);moveStick(e)});
stickEl.addEventListener('pointermove',e=>{if(stick.pointer===e.pointerId)moveStick(e)});
function resetInput(){keys.clear(); stick.pointer=null; stick.x=stick.y=0; if (knob) knob.style.transform='';}
function resetStick(e){if(stick.pointer!==e.pointerId)return;stick.pointer=null;stick.x=stick.y=0;knob.style.transform='';}
stickEl.addEventListener('pointerup',resetStick);stickEl.addEventListener('pointercancel',resetStick);stickEl.addEventListener('lostpointercapture',resetStick);
function updateHud(){ $('remaining').textContent=String(state.enemies.length-state.kills).padStart(2,'0');$('health').style.width=state.player.hp+'%';$('energy').style.width=state.player.energy+'%';$('skill').classList.toggle('disabled',state.player.energy<100); }
function checkEnd(){ if(state.status==='victory' && !paused){save = recordVictory(save, state.time); persist(); endOverlay('Rooftop secure',`All hostiles eliminated. Time: ${Math.floor(state.time)} seconds. Best: ${Math.floor(save.bestTime)} seconds.`, 'PLAY AGAIN');} else if(state.player.hp<=0){state.status='defeat';endOverlay('Mission failed','The city is unforgiving. Regroup and try again.','TRY AGAIN');} }
function update(dt){
  const p=state.player; state.time+=dt; if(state.time>7)$('hint').classList.add('hidden');
  for(const key of ['attackCooldown','dodgeCooldown','dodgeTime','invulnerable','swing'])p[key]=Math.max(0,p[key]-dt);
  const move=movement(); if(p.dodgeTime>0){p.x+=p.dx*440*dt;p.y+=p.dy*440*dt;} else {p.x+=move.x*175*dt;p.y+=move.y*175*dt;if(move.x)p.facing=Math.sign(move.x); if(Math.hypot(move.x,move.y)>.2){footTimer-=dt;if(footTimer<=0){effect('step');footTimer=.32;}}}
  p.x=clamp(p.x,100,900);p.y=clamp(p.y,260,510);
  state.enemies.forEach(e=>{
    if(e.hp<=0)return;e.flash=Math.max(0,e.flash-dt);e.timer-=dt; const d=distance(p,e);
    if(e.state==='stunned'){if(e.timer<=0)e.state='approach';return;}
    if(e.state==='approach'){if(d>72){e.x+=(p.x-e.x)/d*47*dt;e.y+=(p.y-e.y)/d*47*dt;} else if(e.timer<=0){e.state='windup';e.timer=.85;}}
    else if(e.state==='windup' && e.timer<=0){if(d<105 && p.invulnerable<=0){p.hp=Math.max(0,p.hp-16);p.invulnerable=.55;state.shake=7;burst(p.x,p.y-50,'#ff5264',12);label(p.x,p.y-120,'−16','#ff8991');effect('hurt');updateHud();} else if(d<120 && p.invulnerable>0){label(p.x,p.y-120,'EVADE','#c3edf8');} e.state='recover';e.timer=1.1;checkEnd();}
    else if(e.state==='recover' && e.timer<=0){e.state='approach';e.timer=.3;}
  });
  state.particles.forEach(p=>{p.x+=p.vx*dt;p.y+=p.vy*dt;p.vy+=90*dt;p.life-=dt});state.particles=state.particles.filter(p=>p.life>0);
  state.messages.forEach(m=>{m.y-=35*dt;m.life-=dt});state.messages=state.messages.filter(m=>m.life>0);state.shake=Math.max(0,state.shake-20*dt);
}
function ellipse(x,y,rx,ry,color){ctx.fillStyle=color;ctx.beginPath();ctx.ellipse(x,y,rx,ry,0,0,Math.PI*2);ctx.fill()}
function drawEnemy(e){
  const x=e.x,y=e.y; ellipse(x,y+3,35,11,'#0008');
  if(e.state==='windup'){const progress=1-e.timer/.85;ctx.strokeStyle=`rgba(255,65,79,${.5+progress*.5})`;ctx.lineWidth=3;ctx.beginPath();ctx.ellipse(x,y,62+progress*12,25+progress*5,0,0,Math.PI*2);ctx.stroke();ctx.fillStyle='#f55';ctx.font='bold 22px sans-serif';ctx.textAlign='center';ctx.fillText('!',x,y-130);}
  ctx.save();ctx.translate(x,y);
  if (sentinel.complete && sentinel.naturalWidth) {
    if (e.flash > 0) ctx.globalAlpha = .55;
    const bob = e.state === 'approach' ? Math.sin(state.time * 5 + x) * 2 : 0;
    ctx.drawImage(sentinel, -50, -112 + bob, 100, 112);
    ctx.globalAlpha = 1;
  } else { ctx.fillStyle='#778591'; ctx.fillRect(-18,-80,36,76); }
  ctx.restore();
  ctx.fillStyle='#111b';ctx.fillRect(x-26,y-120,52,4);ctx.fillStyle='#f36670';ctx.fillRect(x-26,y-120,52*e.hp/3,4);
}
function drawPlayer(p){
  ellipse(p.x,p.y+3,37,12,'#0009');
  if(p.invulnerable>0){ctx.strokeStyle='rgba(194,235,255,.45)';ctx.lineWidth=2;ctx.beginPath();ctx.ellipse(p.x,p.y,45,17,0,0,Math.PI*2);ctx.stroke();}
  ctx.save();ctx.translate(p.x,p.y);if(p.facing<0)ctx.scale(-1,1);if(p.dodgeTime>0)ctx.globalAlpha=.65;
  const bob=Math.sin(state.time*5)*2; if(fighter.complete && fighter.naturalWidth)ctx.drawImage(fighter,-115,-154+bob,154,154); else {ctx.fillStyle='#c9d2da';ctx.fillRect(-12,-90,24,80);}
  ctx.restore();
  if(p.swing>0){const a=1-p.swing/.3;ctx.save();ctx.translate(p.x,p.y-45);ctx.scale(p.facing,1);ctx.rotate(-.7+a*1.3);ctx.strokeStyle=`rgba(255,69,85,${Math.min(1,p.swing*5)})`;ctx.lineWidth=10;ctx.shadowColor='#ff2345';ctx.shadowBlur=20;ctx.beginPath();ctx.arc(0,0,78,-1.2,1.1);ctx.stroke();ctx.strokeStyle='#fff3ec';ctx.lineWidth=2;ctx.beginPath();ctx.arc(0,0,78,-1.2,1.1);ctx.stroke();ctx.restore();}
}
function render(){ctx.setTransform(1,0,0,1,0,0);ctx.clearRect(0,0,canvas.width,canvas.height);const scale=Math.min(canvas.width/W,canvas.height/H);ctx.setTransform(scale,0,0,scale,(canvas.width-W*scale)/2,(canvas.height-H*scale)/2);ctx.save();if(state.shake>0 && !save.reducedMotion)ctx.translate((Math.random()-.5)*state.shake,(Math.random()-.5)*state.shake);
  const actors=state.enemies.filter(e=>e.hp>0).map(e=>({y:e.y,draw:()=>drawEnemy(e)}));actors.push({y:state.player.y,draw:()=>drawPlayer(state.player)});actors.sort((a,b)=>a.y-b.y).forEach(a=>a.draw());
  state.particles.forEach(p=>{ctx.globalAlpha=Math.max(0,p.life/p.max);ctx.fillStyle=p.color;ctx.fillRect(p.x,p.y,3,3)});ctx.globalAlpha=1;
  state.messages.forEach(m=>{ctx.globalAlpha=Math.min(1,m.life*2);ctx.fillStyle=m.color;ctx.textAlign='center';ctx.font='bold 16px sans-serif';ctx.fillText(m.text,m.x,m.y)});ctx.globalAlpha=1;ctx.restore();
}
function loop(timestamp){if(!active||paused)return; const dt=last?Math.min((timestamp-last)/1000,.05):0;last=timestamp;update(dt);render();if(!paused)frameId = requestAnimationFrame(loop);}
