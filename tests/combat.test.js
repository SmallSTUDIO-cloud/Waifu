import test from 'node:test';
import assert from 'node:assert/strict';
import { clamp, distance, inRange, newEncounter, damageEnemy, dodgeDirection } from '../src/combat.js';
test('distance and range use both axes', () => { assert.equal(distance({x:0,y:0},{x:3,y:4}),5); assert.equal(inRange({x:0,y:0},{x:3,y:4},5),true); assert.equal(inRange({x:0,y:0},{x:3,y:4},4),false); });
test('clamp respects bounds', () => { assert.equal(clamp(-2,0,1),0); assert.equal(clamp(2,0,1),1); });
test('a defeated enemy counts only once and clearing all wins', () => { const s = newEncounter(); const e = s.enemies[0]; damageEnemy(s,e,99); damageEnemy(s,e,99); assert.equal(s.kills,1); s.enemies.slice(1).forEach(e => damageEnemy(s,e,99)); assert.equal(s.status,'victory'); });
test('encounters have independent state', () => { const a = newEncounter(), b = newEncounter(); a.player.hp = 1; assert.equal(b.player.hp,100); });

test('dodging respects vertical input and normalizes diagonals', () => { assert.deepEqual(dodgeDirection({x:0,y:-1},1),{x:0,y:-1}); assert.deepEqual(dodgeDirection({x:0,y:0},-1),{x:-1,y:0}); const v=dodgeDirection({x:1,y:1},1); assert.ok(Math.abs(Math.hypot(v.x,v.y)-1)<1e-10); });
