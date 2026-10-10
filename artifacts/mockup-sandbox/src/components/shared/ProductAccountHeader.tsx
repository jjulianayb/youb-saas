type ProductAccountHeaderProps = {
  organizationName: string;
  displayName: string;
  roleLabel: string;
  onLogout: () => void;
};

export default function ProductAccountHeader({ organizationName, displayName, roleLabel, onLogout }: ProductAccountHeaderProps) {
  return (
    <header className="youb-app-topbar youb-role-topbar">
      <div className="youb-brand" aria-label="youB"><span>you</span><b>B</b></div>
      <div className="youb-role-context">
        <strong>{organizationName}</strong>
        <small>{displayName} · {roleLabel}</small>
      </div>
      <button className="youb-role-logout" onClick={onLogout} type="button">Sair</button>
    </header>
  );
}
