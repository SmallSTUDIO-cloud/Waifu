import json,struct,sys
if len(sys.argv) != 2:
 raise SystemExit('Usage: python repack-motion.py OUTPUT.glb')
p=sys.argv[1]
b=open(p,'rb').read(); jl=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+jl]); binary=b[20+jl+8:]; indices=set()
for a in j['animations']:
 for sam in a['samplers']: indices.update((sam['input'],sam['output']))
for skin in j['skins']:
 if 'inverseBindMatrices' in skin: indices.add(skin['inverseBindMatrices'])
for mesh in j['meshes']:
 for prim in mesh['primitives']:
  indices.update(prim['attributes'].values())
  if 'indices' in prim: indices.add(prim['indices'])
  for target in prim.get('targets',[]): indices.update(target.values())
remap={old:i for i,old in enumerate(sorted(indices))}; newacc=[];data=bytearray(); newviews=[]
comps={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT2':4,'MAT3':9,'MAT4':16}; size={5120:1,5121:1,5122:2,5123:2,5125:4,5126:4}
for old in sorted(indices):
 a=j['accessors'][old].copy();v=j['bufferViews'][a['bufferView']]; stride=v.get('byteStride',size[a['componentType']]*comps[a['type']]); length=size[a['componentType']]*comps[a['type']];start=v.get('byteOffset',0)+a.get('byteOffset',0)
 while len(data)%4:data.append(0)
 off=len(data)
 for idx in range(a['count']): data.extend(binary[start+stride*idx:start+stride*idx+length])
 newviews.append({'buffer':0,'byteOffset':off,'byteLength':len(data)-off});a['bufferView']=len(newviews)-1;a.pop('byteOffset',None);newacc.append(a)
for a in j['animations']:
 for sam in a['samplers']:
  sam['input']=remap[sam['input']];sam['output']=remap[sam['output']]
for skin in j['skins']:
 if 'inverseBindMatrices' in skin:skin['inverseBindMatrices']=remap[skin['inverseBindMatrices']]
for mesh in j['meshes']:
 for prim in mesh['primitives']:
  prim['attributes']={k:remap[v] for k,v in prim['attributes'].items()}
  if 'indices' in prim:prim['indices']=remap[prim['indices']]
  for t in prim.get('targets',[]):
   for k in t:t[k]=remap[t[k]]
j['accessors']=newacc;j['bufferViews']=newviews;j['buffers']=[{'byteLength':len(data)}]
while len(data)%4:data.append(0)
jb=json.dumps(j,separators=(',',':')).encode();jb+=b' '*((-len(jb))%4)
with open(p,'wb') as f:f.write(struct.pack('<4sII',b'glTF',2,12+8+len(jb)+8+len(data)));f.write(struct.pack('<I4s',len(jb),b'JSON'));f.write(jb);f.write(struct.pack('<I4s',len(data),b'BIN\x00'));f.write(data)
print('saved',len(jb)+len(data),'bytes accessors',len(newacc))
