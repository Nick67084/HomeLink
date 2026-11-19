const test=require('node:test');
const assert=require('node:assert/strict');
const app=require('../src/server');
const http=require('node:http');
async function withServer(fn){
 const server=http.createServer(app);
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 try {await fn(`http://127.0.0.1:${server.address().port}`);} finally {await new Promise(resolve=>server.close(resolve));}
}
test('unknown endpoint responds 404 JSON',async()=>withServer(async base=>{
 const r=await fetch(base+'/api/does-not-exist');assert.equal(r.status,404);assert.equal((await r.json()).error,'Route not found');
}));
test('protected endpoint requires authentication',async()=>withServer(async base=>{
 const r=await fetch(base+'/api/me');assert.equal(r.status,401);assert.equal((await r.json()).error,'Authentication required');
}));
test('registration rejects invalid fields without database access',async()=>withServer(async base=>{
 const r=await fetch(base+'/api/auth/register',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:'not-email'})});
 assert.equal(r.status,400);
}));
