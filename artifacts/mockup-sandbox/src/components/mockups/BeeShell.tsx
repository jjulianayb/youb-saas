import { useState, type FormEvent } from "react";
import { Send, ShieldCheck, Sparkles, X } from "lucide-react";

export type BeeContext = { userName: string; organizationName: string; role: string; capabilities: string[]; employeeLinked: boolean; screen: string };
type BeeShellProps = { context: BeeContext; avatarUrl?: string | null; avatarLabel?: string; onSubmit?: (message: string) => void };

function BeeAvatar({ avatarUrl, avatarLabel = "Bee" }: { avatarUrl?: string | null; avatarLabel?: string }) { return avatarUrl ? <img src={avatarUrl} alt="Avatar da Bee" className="h-10 w-10 rounded-2xl object-cover" /> : <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-primary text-sm font-bold text-primary-foreground">{avatarLabel.slice(0, 2).toUpperCase()}</div>; }

export default function BeeShell({ context, avatarUrl, avatarLabel, onSubmit }: BeeShellProps) {
  const [open, setOpen] = useState(false); const [message, setMessage] = useState(""); const [sent, setSent] = useState<string | null>(null);
  function submit(event: FormEvent<HTMLFormElement>) { event.preventDefault(); const value = message.trim(); if (!value) return; setSent(value); setMessage(""); onSubmit?.(value); }
  return <div className="relative">
    {open && <section className="absolute bottom-16 right-0 z-10 w-[min(360px,calc(100vw-2rem))] overflow-hidden rounded-3xl border border-border bg-card text-card-foreground shadow-2xl">
      <header className="flex items-start justify-between bg-primary p-5 text-primary-foreground"><div className="flex gap-3"><BeeAvatar avatarUrl={avatarUrl} avatarLabel={avatarLabel} /><div><p className="text-xs font-bold uppercase tracking-[0.16em] text-primary-foreground/70">Bee · Assistente</p><h2 className="mt-1 text-lg font-bold">Estou aqui para ajudar</h2></div></div><button aria-label="Fechar Bee" className="rounded-full p-1 text-primary-foreground/80 hover:bg-primary-foreground/10" onClick={() => setOpen(false)}><X size={18} /></button></header>
      <div className="space-y-4 p-5"><div className="rounded-2xl bg-muted p-3 text-xs text-muted-foreground"><div className="flex items-center gap-2 font-semibold text-foreground"><ShieldCheck size={15} className="text-emerald-600" /> Contexto permitido</div><p className="mt-2">{context.userName} · {context.role}</p><p>{context.organizationName} · tela {context.screen}</p><p className="mt-1 text-muted-foreground">{context.employeeLinked ? "Perfil de colaborador vinculado" : "Perfil de colaborador ainda não vinculado"}</p></div>
      {sent ? <div className="rounded-2xl bg-secondary p-3 text-sm text-secondary-foreground"><p className="font-semibold">Mensagem recebida</p><p className="mt-1">{sent}</p><p className="mt-2 text-xs text-muted-foreground">A resposta e as fontes aparecerão quando o contrato de inteligência estiver conectado.</p></div> : <div className="rounded-2xl border border-dashed border-border p-4 text-sm text-muted-foreground">Pergunte à Bee sobre desenvolvimento, tarefas ou próximos passos. A Bee só poderá agir dentro das permissões do contexto.</div>}
      <div className="flex flex-wrap gap-2 text-xs">{context.capabilities.slice(0, 3).map((capability) => <span key={capability} className="rounded-full bg-muted px-2.5 py-1 text-muted-foreground">{capability}</span>)}</div><form className="flex gap-2" onSubmit={submit}><input aria-label="Mensagem para a Bee" className="min-w-0 flex-1 rounded-xl border border-input bg-background px-3 py-2 text-sm text-foreground outline-none focus:ring-2 focus:ring-ring" value={message} onChange={(event) => setMessage(event.target.value)} placeholder="Pergunte à Bee..." /><button aria-label="Enviar mensagem" className="rounded-xl bg-primary px-3 text-primary-foreground disabled:opacity-40" disabled={!message.trim()}><Send size={16} /></button></form></div>
    </section>}
    <button className="flex items-center gap-2 rounded-full bg-primary px-4 py-3 text-sm font-bold text-primary-foreground shadow-lg transition hover:-translate-y-0.5 hover:opacity-90" onClick={() => setOpen(!open)}><span className="flex h-7 w-7 items-center justify-center rounded-full bg-primary-foreground/15"><Sparkles size={15} /></span> Falar com a Bee</button>
  </div>;
}

export function BeePreview() { return <BeeShell context={{ userName: "Usuária de preview", organizationName: "Organização de preview", role: "Colaborador", capabilities: ["read:own_profile"], employeeLinked: false, screen: "preview" }} avatarLabel="B" />; }
