import test from 'node:test';
import assert from 'node:assert/strict';
import { defaultSave, normalizeSave, loadSave, writeSave, recordVictory } from '../src/save.js';
test('invalid or future save versions fall back safely', () => { assert.deepEqual(normalizeSave({version:2, wins:99}),defaultSave()); assert.deepEqual(loadSave({getItem(){throw Error('blocked')}}),defaultSave()); });
test('save validates numeric data and settings', () => { assert.deepEqual(normalizeSave({version:1,wins:-1,bestTime:NaN,muted:'true',reducedMotion:true}), {...defaultSave(),reducedMotion:true}); });
test('victory tracks the fastest valid completion', () => { let s=recordVictory(defaultSave(),20); s=recordVictory(s,25); s=recordVictory(s,12); assert.equal(s.wins,3);assert.equal(s.bestTime,12);assert.equal(recordVictory(s,-1).wins,3); });
test('blocked storage does not crash the game', () => { assert.equal(writeSave({setItem(){throw Error('quota')}},defaultSave()),false); });
