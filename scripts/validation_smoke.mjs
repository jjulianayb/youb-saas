const base=process.env.SUPABASE_URL, anon=process.env.SUPABASE_ANON_KEY;
const A='dddddddd-dddd-dddd-dddd-dddddddddddd', B='eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
const U={admin:'admin@demo.invalid',rh:'rh@demo.invalid',diretoria:'diretoria@demo.invalid',gestor:'gestor@demo.invalid',colaborador:'colaborador@demo.invalid',noemployee:'noemployee@demo.invalid',tenantb:'tenantb@demo.invalid'};
const password='LocalPass!123'; const fail=m=>{throw Error('SMOKE_FAIL: '+m)};
async function login(email){let r=await fetch(`${base}/auth/v1/token?grant_type=password`,{method:'POST',headers:{apikey:anon,'content-type':'application/json'},body:JSON.stringify({email,password})});if(!r.ok)fail(`login ${email} ${r.status}`);let j=await r.json();let c=JSON.parse(Buffer.from(j.access_token.split('.')[1],'base64url'));if(c.role!=='authenticated'||c.email!==email)fail('JWT claims '+email);return j}
async function get(t,p){let r=await fetch(`${base}/rest/v1/${p}`,{headers:{apikey:anon,Authorization:`Bearer ${t}`}});if(!r.ok)fail(`GET ${p} ${r.status}`);return r.json()}
async function n(name,a,x){if(a.length!==x)fail(`${name}: ${a.length} != ${x}`)}
const T={};for(const [k,e] of Object.entries(U))T[k]=(await login(e)).access_token;
await n('admin A',await get(T.admin,`organizations?select=id&id=eq.${A}`),1);await n('admin B denied',await get(T.admin,`organizations?select=id&id=eq.${B}`),0);
await n('tenant B own',await get(T.tenantb,`organizations?select=id&id=eq.${B}`),1);await n('tenant B A denied',await get(T.tenantb,`organizations?select=id&id=eq.${A}`),0);
await n('manager direct',await get(T.gestor,'employees?select=id&id=eq.dddddddd-0000-0000-0000-000000000011'),1);await n('manager B denied',await get(T.gestor,`employees?select=id&organization_id=eq.${B}`),0);
await n('worker own',await get(T.colaborador,'employees?select=id&id=eq.dddddddd-0000-0000-0000-000000000011'),1);await n('worker other denied',await get(T.colaborador,'employees?select=id&id=eq.dddddddd-0000-0000-0000-000000000010'),0);
await n('no employee fail closed',await get(T.noemployee,`employees?select=id&organization_id=eq.${A}`),0);
await n('diretoria raw assessment denied',await get(T.diretoria,`assessments?select=id&organization_id=eq.${A}`),0);
let w=await fetch(`${base}/rest/v1/organizations`,{method:'POST',headers:{apikey:anon,Authorization:`Bearer ${T.admin}`,'content-type':'application/json',Prefer:'return=minimal'},body:JSON.stringify({id:'ffffffff-ffff-ffff-ffff-ffffffffffff',name:'forbidden',slug:'forbidden',plan:'essencial',status:'active'})});if(w.ok)fail('direct write allowed');
let lo=await fetch(`${base}/auth/v1/logout`,{method:'POST',headers:{apikey:anon,Authorization:`Bearer ${T.colaborador}`}});if(!lo.ok)fail('logout '+lo.status);let su=await fetch(`${base}/auth/v1/user`,{headers:{apikey:anon,Authorization:`Bearer ${T.colaborador}`}});if(su.ok)fail('session survived logout');
console.log('AUTH_REAL=PASS\nJWT_REAL=PASS\nPOSTGREST_RLS_MULTI_TENANT=PASS\nRLS_FAIL_CLOSED=PASS\nDIRECT_WRITE_DENIAL=PASS\nLOGOUT_SESSION=PASS');
