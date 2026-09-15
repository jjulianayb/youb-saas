import { useMemo, useState } from "react";
import {
  Activity, ArrowRight, BarChart3, BookOpen, BrainCircuit, ChevronDown,
  CircleUserRound, ClipboardCheck, Compass, LayoutDashboard, Menu, Search,
  Sparkles, Target, UsersRound, X,
} from "lucide-react";

export type CommercialDemoRole = "RH" | "Gestor" | "Colaborador" | "Diretoria";
type DemoNavItem = { id: string; label: string; icon: typeof LayoutDashboard };

export const COMMERCIAL_DEMO_ROLES: readonly CommercialDemoRole[] = ["RH", "Gestor", "Colaborador", "Diretoria"];
export const DEMO_NAVIGATION: Record<CommercialDemoRole, readonly DemoNavItem[]> = {
  RH: [{ id: "home", label: "Visão geral", icon: LayoutDashboard }, { id: "people", label: "Pessoas", icon: UsersRound }, { id: "cycles", label: "Ciclos", icon: Compass }, { id: "feedback", label: "Feedback 360", icon: Activity }, { id: "pdi", label: "Desenvolvimento", icon: Target }, { id: "readings", label: "Organização Viva", icon: Sparkles }],
  Gestor: [{ id: "home", label: "Meu dia", icon: LayoutDashboard }, { id: "people", label: "Equipe", icon: UsersRound }, { id: "cycles", label: "Avaliações", icon: ClipboardCheck }, { id: "feedback", label: "Feedback 360", icon: Activity }, { id: "pdi", label: "Desenvolvimento", icon: Target }, { id: "bee", label: "Bee", icon: Sparkles }],
  Colaborador: [{ id: "home", label: "Minha jornada", icon: LayoutDashboard }, { id: "cycles", label: "Competências", icon: Compass }, { id: "feedback", label: "Evolução", icon: Activity }, { id: "pdi", label: "Meu PDI", icon: Target }, { id: "bee", label: "Bee", icon: Sparkles }],
  Diretoria: [{ id: "home", label: "Visão executiva", icon: LayoutDashboard }, { id: "readings", label: "Organização Viva", icon: BookOpen }, { id: "recommendations", label: "Recomendações", icon: Target }, { id: "decisions", label: "Decisões", icon: ClipboardCheck }, { id: "impact", label: "Impacto", icon: BarChart3 }, { id: "bee", label: "Bee", icon: Sparkles }],
};

export function demoNavigationForRole(role: CommercialDemoRole): readonly DemoNavItem[] { return DEMO_NAVIGATION[role]; }
export function demoRoleLabel(role: CommercialDemoRole): string { return ({ RH: "RH / Admin", Gestor: "Gestor", Colaborador: "Colaborador", Diretoria: "Diretoria" })[role]; }
export function mobileNavigationState(open: boolean): { ariaExpanded: boolean; visibility: "hidden" | "visible" } { return { ariaExpanded: open, visibility: open ? "visible" : "hidden" }; }

const roleCopy: Record<CommercialDemoRole, { eyebrow: string; hello: string; title: string; description: string; quote: string }> = {
  RH: { eyebrow: "CENTRO DE ORQUESTRAÇÃO", hello: "Bom dia, Juliana.", title: "Sua organização está falando.", description: "Conectamos sinais, contexto e desenvolvimento para mostrar onde sua atenção gera mais impacto.", quote: "Pessoas não são números. Mas decisões melhores precisam de evidências." },
  Gestor: { eyebrow: "MEU DIA", hello: "Bom dia, Carlos.", title: "Liderar começa por enxergar.", description: "Seu time, suas conversas e seus próximos passos organizados sem ruído.", quote: "Clareza não simplifica pessoas. Ela melhora a qualidade da decisão." },
  Colaborador: { eyebrow: "MINHA JORNADA", hello: "Olá, Mariana.", title: "Seu próximo passo começa aqui.", description: "Um espaço pessoal para acompanhar evolução, competências e desenvolvimento no seu ritmo.", quote: "Evolução ganha força quando você consegue reconhecer o próprio caminho." },
  Diretoria: { eyebrow: "VISÃO EXECUTIVA", hello: "Bom dia, Juliana.", title: "Decida com contexto, não com ruído.", description: "Uma leitura agregada da organização, com hipóteses e evidências claramente separadas.", quote: "Estratégia de pessoas é estratégia de negócio quando chega à decisão." },
};

const metrics: Record<CommercialDemoRole, Array<{ label: string; value: string; detail: string; tone: string }>> = {
  RH: [{ label: "Pessoas", value: "42", detail: "no escopo demonstrativo", tone: "violet" }, { label: "Atenções", value: "03", detail: "pedem contexto hoje", tone: "pink" }, { label: "Desenvolvimento", value: "84%", detail: "ações acompanhadas", tone: "amber" }],
  Gestor: [{ label: "Equipe", value: "08", detail: "liderados diretos", tone: "violet" }, { label: "Conversas", value: "02", detail: "pedem preparação", tone: "pink" }, { label: "PDIs", value: "06", detail: "em acompanhamento", tone: "amber" }],
  Colaborador: [{ label: "Meu PDI", value: "01", detail: "objetivo em andamento", tone: "violet" }, { label: "Próximo passo", value: "03", detail: "ações definidas", tone: "pink" }, { label: "Evolução", value: "72%", detail: "do ciclo demonstrativo", tone: "amber" }],
  Diretoria: [{ label: "Leituras", value: "04", detail: "agregadas e abertas", tone: "violet" }, { label: "Decisões", value: "02", detail: "aguardam revisão", tone: "pink" }, { label: "Impacto", value: "+18%", detail: "evolução observada", tone: "amber" }],
};

type DemoExperienceContent = {
  nextMoves: Array<{ title: string; detail: string }>;
  beeTitle: string;
  beeDetail: string;
};

const experienceContent: Record<CommercialDemoRole, DemoExperienceContent> = {
  RH: {
    nextMoves: [
      { title: "Revisar a cadência de conversas", detail: "Prioridade demonstrativa" },
      { title: "Aprofundar evidências antes de agir", detail: "Contexto disponível" },
      { title: "Acompanhar evolução do ciclo", detail: "Contexto disponível" },
    ],
    beeTitle: "Posso organizar as evidências antes da sua decisão.",
    beeDetail: "Sem inferências ocultas. Sem decisão automática.",
  },
  Gestor: {
    nextMoves: [
      { title: "Preparar a próxima conversa individual", detail: "Ação de liderança" },
      { title: "Revisar o avanço dos PDIs da equipe", detail: "Acompanhamento semanal" },
      { title: "Registrar os combinados da semana", detail: "Próximo passo" },
    ],
    beeTitle: "Posso preparar o contexto da sua próxima conversa.",
    beeDetail: "Você conduz. Eu organizo os pontos relevantes.",
  },
  Colaborador: {
    nextMoves: [
      { title: "Registrar avanço no meu objetivo", detail: "Meu desenvolvimento" },
      { title: "Praticar a competência escolhida", detail: "Próximo passo" },
      { title: "Preparar meu próximo check-in", detail: "Minha jornada" },
    ],
    beeTitle: "Posso ajudar você a transformar seu objetivo em próximos passos.",
    beeDetail: "Seu espaço pessoal de desenvolvimento.",
  },
  Diretoria: {
    nextMoves: [
      { title: "Revisar a leitura organizacional", detail: "Prioridade demonstrativa" },
      { title: "Comparar evidências antes de decidir", detail: "Contexto disponível" },
      { title: "Acompanhar o impacto da decisão", detail: "Evolução observada" },
    ],
    beeTitle: "Posso organizar as evidências antes da sua decisão.",
    beeDetail: "Sem inferências ocultas. Sem decisão automática.",
  },
};

export function demoExperienceContentForRole(role: CommercialDemoRole): DemoExperienceContent {
  return experienceContent[role];
}

const people = [
  { name: "Mariana", role: "Liderança", x: 15, y: 25, tone: "pink" },
  { name: "Carlos", role: "Gestor", x: 45, y: 10, tone: "violet" },
  { name: "Ana", role: "Especialista", x: 70, y: 34, tone: "mint" },
  { name: "Pedro", role: "Analista", x: 30, y: 70, tone: "amber" },
  { name: "Luiza", role: "Analista", x: 68, y: 76, tone: "pink" },
];

function Logo() { return <div className="cv-logo" aria-label="youB"><strong>youB</strong><span /><small>HUMAN INTELLIGENCE<br />PLATFORM</small></div>; }
function DemoAvatar({ tone = "violet" }: { tone?: string }) { return <span className={`cv-avatar cv-avatar--${tone}`}><CircleUserRound /></span>; }
function MetricCard({ item }: { item: { label: string; value: string; detail: string; tone: string } }) { return <article className={`cv-metric cv-tone-${item.tone}`}><span className="cv-metric__dot" /><div><p>{item.label}</p><strong>{item.value}</strong><small>{item.detail}</small></div><ArrowRight /></article>; }

function OrganizationLiving({ role }: { role: CommercialDemoRole }) {
  if (role === "Colaborador") return <section className="cv-personal" aria-label="Jornada pessoal"><header><div><p>MINHA EVOLUÇÃO</p><h2>O caminho que estou construindo</h2></div><span>Dados demonstrativos</span></header><div className="cv-personal__steps">{["Reconhecer forças", "Definir objetivo", "Praticar", "Registrar evolução"].map((label, index) => <article key={label}><b>{index + 1}</b><strong>{label}</strong><small>{index < 2 ? "Em andamento" : "Próximo passo"}</small></article>)}</div></section>;
  return <section className="cv-living" aria-label="Organização Viva"><header><div><p>ORGANIZAÇÃO VIVA</p><h2>Veja relações, sinais e movimento</h2><span>Observar → Compreender → Simular → Agir</span></div><button type="button">Explorar leitura <ArrowRight /></button></header><div className="cv-living__body"><div className="cv-map"><svg viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true"><path d="M15 25 C28 10 35 12 45 10 M45 10 C56 15 59 24 70 34 M15 25 C12 46 18 63 30 70 M30 70 C43 83 57 85 68 76 M70 34 C77 48 76 64 68 76 M45 10 C44 36 38 54 30 70" /></svg>{people.map((person) => <button key={person.name} type="button" className="cv-node" style={{ left: `${person.x}%`, top: `${person.y}%` }}><DemoAvatar tone={person.tone} /><strong>{person.name}</strong><small>{person.role}</small></button>)}</div><aside className="cv-insight"><div className="cv-insight__label"><Sparkles /> LEITURA EM DESTAQUE</div><h3>O ritmo de acompanhamento não está igual entre as equipes.</h3><p>Há sinais demonstrativos de diferença na cadência de conversas. Isso ainda é uma <strong>hipótese</strong>, não uma conclusão.</p><dl><div><dt>Evidências conectadas</dt><dd>4 fontes</dd></div><div><dt>Confiança atual</dt><dd>Moderada</dd></div></dl><button type="button">Compreender esta leitura <ArrowRight /></button></aside></div></section>;
}

function BeePanel({ content }: { content: DemoExperienceContent }) { return <aside className="cv-bee"><div className="cv-bee__orb"><BrainCircuit /></div><div><p>BEE · INTELIGÊNCIA CONTEXTUAL</p><h3>{content.beeTitle}</h3><small>{content.beeDetail}</small></div><button type="button">Perguntar à Bee <Sparkles /></button></aside>; }

export default function CommercialV1Demo() {
  const [role, setRole] = useState<CommercialDemoRole>("RH");
  const [active, setActive] = useState("home");
  const [mobileOpen, setMobileOpen] = useState(false);
  const copy = roleCopy[role];
  const content = demoExperienceContentForRole(role);
  const navigation = useMemo(() => demoNavigationForRole(role), [role]);
  const mobileState = mobileNavigationState(mobileOpen);
  function selectRole(nextRole: CommercialDemoRole) { setRole(nextRole); setActive("home"); setMobileOpen(false); }
  return <main className="cv-shell">
    <header className="cv-topbar"><Logo /><nav aria-label="Navegação principal">{navigation.slice(0, 5).map((item) => <button type="button" key={item.id} aria-current={active === item.id ? "page" : undefined} className={active === item.id ? "active" : ""} onClick={() => setActive(item.id)}>{item.label}</button>)}</nav><div className="cv-topbar__actions"><button className="cv-search" type="button" aria-label="Buscar ou perguntar à Bee"><Search /><span>Buscar ou perguntar à Bee...</span></button><DemoAvatar /><button className="cv-menu" type="button" aria-label={mobileOpen ? "Fechar menu" : "Abrir menu"} aria-expanded={mobileState.ariaExpanded} onClick={() => setMobileOpen((value) => !value)}>{mobileOpen ? <X /> : <Menu />}</button></div></header>
    <nav className={`cv-mobile-nav ${mobileState.visibility}`} aria-label="Navegação móvel">{navigation.map((item) => <button type="button" key={item.id} className={active === item.id ? "active" : ""} onClick={() => { setActive(item.id); setMobileOpen(false); }}>{item.label}</button>)}</nav>
    <div className="cv-rolebar"><span>EXPERIÊNCIA</span><div>{COMMERCIAL_DEMO_ROLES.map((item) => <button type="button" key={item} aria-pressed={role === item} className={role === item ? "active" : ""} onClick={() => selectRole(item)}>{demoRoleLabel(item)}</button>)}</div><button type="button" className="cv-company">Acme Labs · demonstração <ChevronDown /></button></div>
    <section className="cv-hero"><div className="cv-hero__mist" /><div className="cv-hero__copy"><p>{copy.eyebrow}</p><h1>{copy.hello}</h1><h2>{copy.title}</h2><span>{copy.description}</span></div><blockquote>“{copy.quote}”<i /><small>youB · Inteligência Proprietária de DHO</small></blockquote></section>
    <div className="cv-canvas"><section className="cv-metrics">{metrics[role].map((item) => <MetricCard key={item.label} item={item} />)}</section><OrganizationLiving role={role} /><section className="cv-bottom"><article><header><div><p>PRÓXIMOS MOVIMENTOS</p><h2>{role === "Colaborador" ? "Meus próximos passos" : "O que merece atenção agora"}</h2></div><span>3 itens</span></header>{content.nextMoves.map((item, index) => <button type="button" key={item.title}><b>0{index + 1}</b><span><strong>{item.title}</strong><small>{item.detail}</small></span><ArrowRight /></button>)}</article><BeePanel content={content} /></section></div>
    <footer className="cv-mobile-bottom">{navigation.slice(0, 5).map((item) => { const Icon = item.icon; return <button type="button" key={item.id} className={active === item.id ? "active" : ""} onClick={() => setActive(item.id)}><Icon /><span>{item.label.split(" ")[0]}</span></button>; })}</footer>
  </main>;
}

export function CommercialV1DemoPreview() { return <CommercialV1Demo />; }
