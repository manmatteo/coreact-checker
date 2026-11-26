# Translate a workbench Rocq export into a development (see syntax.elpi):
#   python3 elpi/from_rocq.py joy_of_cats.v elpi/joy.elpi
import re,sys
TOK=re.compile(r"ltac:\(subst_all_in|->|[A-Za-z_][A-Za-z0-9_']*|[(),:=Σ{}]")
class P:
    def __init__(s,txt): s.t=TOK.findall(txt); s.i=0
    def pk(s,k=0): return s.t[s.i+k] if s.i+k<len(s.t) else None
    def nx(s): s.i+=1; return s.t[s.i-1]
    def ex(s,x): y=s.nx(); assert y==x,(x,y,s.t[max(0,s.i-8):s.i+8])
    def binders(s):
        out=[]
        while s.pk()=='(':
            s.nx(); ns=[]
            while s.pk()!=':': ns.append(s.nx())
            s.nx(); ty=s.atom(); s.ex(')')
            out+=[(n,ty) for n in ns]
        return out
    def atom(s):
        ws=[]
        while s.pk() not in (None,')',',','->','=','(',':'): ws.append(s.nx())
        if s.pk()=='=':
            s.nx(); return ('=',ws[0],s.nx())
        return tuple(ws)
    def neg(s):            # -> ('all',n,ty,F) ('ifeq',n,a,b,F) ('imp',N,F) or pos
        k=s.pk()
        if k=='forall':
            s.nx(); bs=s.binders(); s.ex(','); return wrap(bs,s.neg(),'all','ifeq')
        if k=='ltac:(subst_all_in':
            s.nx(); s.ex('('); f=s.neg(); s.ex(')'); s.ex(')'); return f
        if k=='(':
            s.nx(); n=s.neg(); s.ex(')')
            if s.pk()=='->': s.nx(); return ('imp',n,s.neg())
            return n
        return s.pos()
    def pos(s):
        k=s.pk()
        if k=='Σ':
            s.nx(); bs=s.binders(); s.ex(','); return wrap(bs,s.pos(),'ex','eqn')
        if k=='ltac:(subst_all_in':
            s.nx(); s.ex('('); f=s.pos(); s.ex(')'); s.ex(')'); return f
        if k=='True': s.nx(); return ('tt',)
        a=s.atom()
        return ('eqn','_',a[1],a[2],('tt',)) if a[0]=='=' else ('ex','_',a,('tt',))
def wrap(bs,f,q,e):
    for n,ty in reversed(bs):
        f=(e,n,ty[1],ty[2],f) if ty[0]=='=' else (q,n,ty,f)
    return f
def lv(n): return "x_"+n if n!='_' else '_'
def ty(t): return f's "{t[0]}" [{", ".join(lv(x) for x in t[1:])}]'
def fm(f):
    k=f[0]
    if k in('all','ex'): return f"{k} ({ty(f[2])}) ({lv(f[1])}\\ {fm(f[3])})"
    if k in('ifeq','eqn'): return f"{'all' if k=='ifeq' else 'ex'} (eq {lv(f[2])} {lv(f[3])}) (_\\ {fm(f[4])})"
    if k=='imp': return f"imp ({fm(f[1])}) ({fm(f[2])})"
    return 'tt'
CNT=[0]
def fresh(n):
    CNT[0]+=1; return f"x{CNT[0]}_{n}"
def binders_of(f):
    o=[]
    while f[0] in('all','ifeq'):
        o.append(f[1] if f[0]=='all' else '_')
        f=f[-1]
    return o
def bind(ctor,ns,env,k):   # bind ns with ctor, run k(env')
    env=dict(env); fs=[]
    for n in ns:
        x=fresh(n) if n!='_' else '_'; env[n]=x; fs.append(x)
    r=k(env)
    for x in reversed(fs): r=f"{ctor} ({x}\\ {r})"
    return r
def nm(r): return 'r_'+r
class Pr:
    def __init__(s,lines): s.l=[x.strip() for x in lines]; s.i=0
    def body(s,prem,env):
        prem=dict(prem); env=dict(env)
        while True:
            x=s.l[s.i]; s.i+=1
            if x=='intros_sigma ().': continue
            m=re.match(r'assert \((\w+) : (.*)\)\. \{$',x)
            if m:
                f=P(m[2]).neg()
                prem[m[1]]=bind('intro',binders_of(f),env,lambda e:s.body(prem,e))
                assert s.l[s.i]=='}',s.l[s.i]; s.i+=1; continue
            m=re.match(r"set \((\S+) := (\S+) : (.*)\)\.$",x)
            if m: env[m[1]]=env[m[2]]; continue
            m=re.match(r"rename (\S+) into (\S+)\.$",x)
            if m: env[m[2]]=env[m[1]]; continue
            m=re.match(r"(?:assert \((\S+) := @(\S+) (.*)\); destruct_sigma \S+ as (.*)\.|destruct_sigma \(@(\S+) ?(.*)\) as (.*)\.)$",x)
            if m:
                r=m[2] or m[5]; args=(m[3] if m[2] else m[6]).split(); pats=(m[4] if m[2] else m[7]).split()
                used.add(r)
                tms=['refl' if y=='eq_refl' else env[y] for y in args if y not in prem]
                pfs=[prem[y] for y in args if y in prem]
                rest=bind('unpack',pats,env,lambda e:s.body(prem,e))
                return f"apply {nm(r)} [{', '.join(tms)}] [{', '.join(pfs)}] ({rest})"
            m=re.match(r'exact (.*)\.$',x)
            if m:
                ws=[w for w in re.findall(r"[\w']+",m[1]) if w!='I']
                return f"done [{', '.join('refl' if w=='eq_refl' else env[w] for w in ws)}]"
            raise Exception('unparsed: '+x)
used=set()
def run(path,out):
    src=open(path).read(); items=[]; names=[]
    sorts=re.findall(r'^Parameter (\w+) : (Type|Vertex.*Type|forall `.*Type)\.$',src,re.M)
    sig=[]
    for n,t in sorts:
        if t.startswith('forall'): ds=re.findall(r'`\(\S+ : (\w+)',t)+[w for w in re.findall(r'\w+',t.split(',')[-1]) if w!='Type']
        else: ds=re.findall(r'\w+',t)[:-1]
        sig.append(f'sort "{n}" ['+', '.join(f'"{d}"' for d in ds)+'].')
    body=src[src.index('Parameter Vertex'):]
    for m in re.finditer(r'^(Parameter (\w+_rule(?:_\d+)?) : (.*)\.$|Lemma (\S+) : (.*)\.\n((?:.*\n)*?)(Qed|Admitted)\.)',body,re.M):
        if m[2]:
            items.append(('axiom',m[2],fm(P(m[3]).neg()),None)); names.append(m[2])
        else:
            f=P(m[5]).neg(); ls=[l for l in m[6].split('\n') if l.strip()]
            if m[7]=='Admitted': print('admitted',m[4]); continue
            items.append(('thm',m[4],fm(f),(lambda pr: bind('intro',binders_of(f),{},lambda e: pr.body({},e)))(Pr(ls)))); names.append(m[4])
    with open(out,'w') as o:
        o.write('% Generated by from_rocq.py; do not edit.\naccumulate checker.\n'+'\n'.join(sig)+'\n')
        for n in names: o.write(f'type {nm(n)} name.\n')
        o.write('development [\n'+',\n'.join(f' {k} {nm(n)} ({f})'+(f' ({pf})' if pf else '') for k,n,f,pf in items)+'\n].\n')
        o.write('main :- check ["cut", "part"].\n')
    print(path.split('/')[-1],'axioms',sum(i[0]=='axiom' for i in items),'theorems',sum(i[0]=='thm' for i in items),'undefined rules:',used-set(names))
run(sys.argv[1],sys.argv[2])
