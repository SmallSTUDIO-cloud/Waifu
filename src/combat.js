export const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
export const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
export const inRange = (a, b, range) => distance(a, b) <= range;
export function dodgeDirection(move, facing) {
  const x = move.x || move.y ? move.x : facing;
  const y = move.y;
  const length = Math.hypot(x, y) || 1;
  return { x: x / length, y: y / length };
}
export function newEncounter() {
  return {
    player: { x: 350, y: 430, hp: 100, energy: 0, facing: 1, attackCooldown: 0, dodgeCooldown: 0, dodgeTime: 0, invulnerable: 0, swing: 0, combo: 0 },
    enemies: [0, 1, 2, 3, 4, 5].map((i) => ({ x: 650 + (i % 3) * 90, y: 320 + Math.floor(i / 3) * 130, hp: 3, state: 'approach', timer: 0.5 + i * .3, flash: 0 })),
    kills: 0, time: 0, status: 'playing', particles: [], messages: [], shake: 0,
  };
}
export function damageEnemy(state, enemy, damage) {
  if (enemy.hp <= 0) return false;
  enemy.hp = Math.max(0, enemy.hp - damage);
  enemy.flash = .15;
  enemy.state = 'stunned'; enemy.timer = .3;
  if (!enemy.hp) state.kills++;
  if (state.kills === state.enemies.length) state.status = 'victory';
  return true;
}
