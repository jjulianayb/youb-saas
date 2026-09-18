import { useEffect } from "react";
import type { ReactNode } from "react";

type RecordDrawerProps = {
  open: boolean;
  onClose: () => void;
  title: string;
  subtitle?: string;
  badge?: ReactNode;
  children: ReactNode;
  footer?: ReactNode;
};

export default function RecordDrawer({ open, onClose, title, subtitle, badge, children, footer }: RecordDrawerProps) {
  useEffect(() => {
    if (!open) return;
    const handleEsc = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    document.addEventListener("keydown", handleEsc);
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", handleEsc);
      document.body.style.overflow = "";
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50">
      <div
        className="absolute inset-0 animate-[fadeIn_0.2s_ease-out] bg-slate-900/30 backdrop-blur-md"
        onClick={onClose}
      />
      <aside
        className="ag-glass absolute right-0 top-0 flex h-full w-full max-w-md flex-col shadow-2xl animate-[slideInRight_0.3s_ease-out]"
      >
        <style>{`
          @keyframes fadeIn { from { opacity: 0 } to { opacity: 1 } }
          @keyframes slideInRight { from { transform: translateX(100%) } to { transform: translateX(0) } }
        `}</style>
        <header className="flex items-start justify-between gap-3 border-b border-white/20 p-5">
          <div className="min-w-0">
            <h2 className="truncate text-lg font-extrabold text-slate-900">{title}</h2>
            {subtitle && <p className="mt-1 text-sm text-slate-500">{subtitle}</p>}
          </div>
          <div className="flex items-center gap-2">
            {badge}
            <button
              className="rounded-lg p-2 text-slate-400 transition hover:bg-white/30 hover:text-slate-700"
              onClick={onClose}
              type="button"
            >
              <svg className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                <path d="M18 6 6 18M6 6l12 12" />
              </svg>
            </button>
          </div>
        </header>
        <div className="flex-1 overflow-y-auto p-5">{children}</div>
        {footer && <footer className="border-t border-white/20 p-5">{footer}</footer>}
      </aside>
    </div>
  );
}

export function DetailField({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="ag-glass-muted rounded-xl p-3">
      <p className="text-xs font-bold uppercase tracking-wide text-slate-400">{label}</p>
      <p className="mt-1 text-sm font-semibold text-slate-800">{value ?? "—"}</p>
    </div>
  );
}

export function DetailSection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="mt-5">
      <h3 className="mb-2 text-xs font-bold uppercase tracking-[0.12em] text-[#2aa6a0]">{title}</h3>
      {children}
    </div>
  );
}
