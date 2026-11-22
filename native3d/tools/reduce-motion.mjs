import { NodeIO } from '@gltf-transform/core';
import { prune } from '@gltf-transform/functions';
const [input, output] = process.argv.slice(2);
if (!input || !output) throw new Error('Usage: node reduce-motion.mjs SOURCE.glb OUTPUT.glb');
const io = new NodeIO(); const doc = await io.read(input);
const wanted = new Set(['Sword_Idle','Walk_Loop','Walk_Formal_Loop','Jog_Fwd_Loop','Sword_Attack','Roll']);
const bones = new Set(['DEF-hips','DEF-spine.001','DEF-spine.002','DEF-spine.003','DEF-neck','DEF-head','DEF-shoulder.L','DEF-upper_arm.L','DEF-forearm.L','DEF-hand.L','DEF-shoulder.R','DEF-upper_arm.R','DEF-forearm.R','DEF-hand.R','DEF-thigh.L','DEF-shin.L','DEF-foot.L','DEF-toe.L','DEF-thigh.R','DEF-shin.R','DEF-foot.R','DEF-toe.R']);
for (const a of doc.getRoot().listAnimations()) {
 if (!wanted.has(a.getName())) { a.dispose(); continue; }
 for (const c of a.listChannels()) if (!bones.has(c.getTargetNode()?.getName()) || (c.getTargetPath() !== 'rotation' && !(c.getTargetNode()?.getName() === 'DEF-hips' && c.getTargetPath() === 'translation'))) c.dispose();
 const used = new Set(a.listChannels().map(c => c.getSampler()));
 for (const sampler of a.listSamplers()) if (!used.has(sampler)) sampler.dispose();
}
// Keep the source skeleton valid for Godot without carrying the mannequin mesh.
const root=doc.getRoot(); const buffer=root.listBuffers()[0];
const accessor=(type, arr)=>doc.createAccessor().setType(type).setArray(arr).setBuffer(buffer);
for (const mesh of root.listMeshes()) {
 for (const prim of mesh.listPrimitives()) prim.dispose();
 const prim=doc.createPrimitive().setAttribute('POSITION',accessor('VEC3',new Float32Array([0,0,0, .001,0,0, 0,.001,0])))
  .setAttribute('JOINTS_0',accessor('VEC4',new Uint16Array(12)))
  .setAttribute('WEIGHTS_0',accessor('VEC4',new Float32Array([1,0,0,0,1,0,0,0,1,0,0,0])))
  .setIndices(accessor('SCALAR',new Uint16Array([0,1,2])));
 mesh.addPrimitive(prim);
}
await doc.transform(prune());
await io.write(output, doc);
console.log(doc.getRoot().listAnimations().map(a=>[a.getName(),a.listChannels().length]));
