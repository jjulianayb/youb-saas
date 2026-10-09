import { useEffect, useState, type ComponentType } from "react";

import { modules as discoveredModules } from "./.generated/mockup-components";
import Onboarding from "./components/mockups/Onboarding";
import EmployeeExperienceRoute from "./components/employee/EmployeeExperienceRoute";
import ExecutiveHomeRoute from "./components/employee/ExecutiveHomeRoute";
import CommercialExperienceRoute from "./components/employee/CommercialExperienceRoute";
import { getAppBasePath, resolveAppRoute } from "./lib/app-paths";

type ModuleMap = Record<string, () => Promise<Record<string, unknown>>>;

function resolveComponent(mod: Record<string, unknown>, name: string): ComponentType | undefined {
  const functions = Object.values(mod).filter((value) => typeof value === "function") as ComponentType[];
  return (mod.default as ComponentType) || (mod.Preview as ComponentType) || (mod[name] as ComponentType) || functions[functions.length - 1];
}

function PreviewRenderer({ componentPath, modules }: { componentPath: string; modules: ModuleMap }) {
  const [Component, setComponent] = useState<ComponentType | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setComponent(null);
    setError(null);
    async function loadComponent() {
      const key = `./components/mockups/${componentPath}.tsx`;
      const loader = modules[key];
      if (!loader) {
        setError(`No component found at ${componentPath}.tsx`);
        return;
      }
      try {
        const mod = await loader();
        if (cancelled) return;
        const name = componentPath.split("/").pop()!;
        const component = resolveComponent(mod, name);
        if (!component) {
          setError(`No exported React component found in ${componentPath}.tsx`);
          return;
        }
        setComponent(() => component);
      } catch (loadError) {
        if (!cancelled) setError(`Failed to load preview.\n${loadError instanceof Error ? loadError.message : String(loadError)}`);
      }
    }
    void loadComponent();
    return () => { cancelled = true; };
  }, [componentPath, modules]);

  if (error) return <pre style={{ color: "red", padding: "2rem", fontFamily: "system-ui" }}>{error}</pre>;
  if (!Component) return null;
  return <Component />;
}

/** One product entry: authenticated users are resumed by Onboarding; others see login. */
function App() {
  const route = resolveAppRoute(window.location.pathname, getAppBasePath());
  if (route.kind === "employee") return <EmployeeExperienceRoute />;
  if (route.kind === "executive") return <ExecutiveHomeRoute />;
  if (route.kind === "commercial") return <CommercialExperienceRoute />;
  if (route.kind === "preview") return <PreviewRenderer componentPath={route.componentPath} modules={discoveredModules} />;
  return <Onboarding />;
}

export default App;
