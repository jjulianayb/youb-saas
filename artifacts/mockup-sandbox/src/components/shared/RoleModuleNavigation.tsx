type RoleModule = "home" | "competency-cycle";

export default function RoleModuleNavigation({ activeModule, onChange }: { activeModule: RoleModule; onChange: (module: RoleModule) => void }) {
  const items: Array<{ id: RoleModule; label: string }> = [
    { id: "home", label: "Início" },
    { id: "competency-cycle", label: "Competências e avaliações" },
  ];
  return (
    <nav aria-label="Navegação principal" className="flex flex-wrap gap-2 border-b border-border bg-background px-5 py-3 sm:px-8">
      {items.map((item) => (
        <button
          key={item.id}
          type="button"
          aria-current={activeModule === item.id ? "page" : undefined}
          onClick={() => onChange(item.id)}
          className={`rounded-full px-4 py-2 text-sm font-semibold transition ${activeModule === item.id ? "bg-primary text-primary-foreground" : "border border-border bg-card text-foreground hover:bg-muted"}`}
        >
          {item.label}
        </button>
      ))}
    </nav>
  );
}

export type { RoleModule };
