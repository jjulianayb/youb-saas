import { useEffect, useState, type ComponentType } from "react";

import { modules as discoveredModules } from "./.generated/mockup-components";
import Onboarding from "./components/mockups/Onboarding";
import EmployeeExperienceRoute from "./components/employee/EmployeeExperienceRoute";
import ExecutiveHomeRoute from "./components/employee/ExecutiveHomeRoute";
import CommercialExperienceRoute from "./components/employee/CommercialExperienceRoute";
import CommercialV1Demo from "./components/commercial/CommercialV1Demo";
import { appPath, getAppBasePath, localAppPath } from "./lib/app-paths";

type ModuleMap = Record<string, () => Promise<Record<string, unknown>>>;

function _resolveComponent(mod: Record<string, unknown>, name: string): ComponentType | undefined {
  const fns = Object.values(mod).filter((v) => typeof v === "function") as ComponentType[];
  return (mod.default as ComponentType) || (mod.Preview as ComponentType) || (mod[name] as ComponentType) || fns[fns.length - 1];
}
function PreviewRenderer({ componentPath, modules }: { componentPath: string; modules: ModuleMap }) {
  const [Component, setComponent] = useState<ComponentType | null>(null); const [error, setError] = useState<string | null>(null);
  useEffect(() => { let cancelled = false; setComponent(null); setError(null); async function loadComponent() { const key = `./components/mockups/${componentPath}.tsx`; const loader = modules[key]; if (!loader) { setError(`No component found at ${componentPath}.tsx`); return; } try { const mod = await loader(); if (cancelled) return; const name = componentPath.split("/").pop()!; const comp = _resolveComponent(mod, name); if (!comp) { setError(`No exported React component found in ${componentPath}.tsx`); return; } setComponent(() => comp); } catch (e) { if (!cancelled) setError(`Failed to load preview.\n${e instanceof Error ? e.message : String(e)}`); } } void loadComponent(); return () => { cancelled = true; }; }, [componentPath, modules]);
  if (error) return <pre style={{ color: "red", padding: "2rem", fontFamily: "system-ui" }}>{error}</pre>;
  if (!Component) return null;
  return <Component />;
}
function getPreviewExamplePath(): string { return appPath("/preview/ComponentName"); }
function getPreviewPath(): string | null { const local = localAppPath(window.location.pathname, getAppBasePath()); const match = local.match(/^\/preview\/(.+)$/); return match ? match[1] : null; }
function Gallery() { return <div className="min-h-screen bg-[var(--youb-surface)] flex items-center justify-center p-8"><div className="max-w-lg text-center"><div className="mx-auto flex w-fit items-baseline gap-1 rounded-2xl bg-[var(--youb-navy)] px-5 py-3 text-white"><span className="text-2xl font-light text-white/75">you</span><span className="text-3xl font-extrabold">B</span></div><p className="mt-6 text-xs font-bold uppercase tracking-[0.16em] text-[var(--youb-teal)]">Commercial V1</p><h1 className="mt-2 text-3xl font-extrabold tracking-tight text-[var(--youb-ink)]">Uma experiência integrada para a youB</h1><p className="mt-3 text-sm leading-6 text-slate-500">Acesse a demonstração ou abra a jornada autenticada correspondente ao seu papel.</p><div className="mt-7 flex flex-wrap justify-center gap-3"><a className="inline-flex rounded-xl bg-[var(--youb-navy)] px-4 py-3 text-sm font-bold text-white" href={appPath("/preview/CommercialV1Demo")}>Ver demo Commercial V1</a><a className="inline-flex rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm font-bold text-slate-700" href={appPath("/commercial")}>Abrir produto autenticado</a><a className="inline-flex rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm font-bold text-slate-700" href={appPath("/preview/Onboarding")}>Login e onboarding</a></div></div></div>; }
function App() { if (window.location.pathname.endsWith("/employee")) return <EmployeeExperienceRoute />; if (window.location.pathname.endsWith("/executive")) return <ExecutiveHomeRoute />; if (window.location.pathname.endsWith("/commercial")) return <CommercialExperienceRoute />; const previewPath = getPreviewPath(); if (previewPath === "Onboarding") return <Onboarding />; if (previewPath === "CommercialV1Demo") return <CommercialV1Demo />; if (previewPath) return <PreviewRenderer componentPath={previewPath} modules={discoveredModules} />; return <Gallery />; }
export default App;
