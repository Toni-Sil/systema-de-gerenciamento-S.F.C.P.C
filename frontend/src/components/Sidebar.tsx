import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  Package,
  ArrowLeftRight,
  BarChart3,
  DollarSign,
  FileText,
  Bell,
  Settings,
} from 'lucide-react';
import { cn } from '@/lib/utils';

const navItems = [
  { to: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/products', icon: Package, label: 'Produtos' },
  { to: '/stock', icon: BarChart3, label: 'Estoque' },
  { to: '/movements', icon: ArrowLeftRight, label: 'Movimentações' },
  { to: '/financial', icon: DollarSign, label: 'Financeiro' },
  { to: '/reports', icon: FileText, label: 'Relatórios' },
  { to: '/alerts', icon: Bell, label: 'Alertas' },
  { to: '/settings', icon: Settings, label: 'Configurações' },
];

export function Sidebar({ open }: { open: boolean }) {
  if (!open) return null;

  return (
    <aside className="w-56 bg-card border-r border-border flex flex-col py-4 shrink-0">
      <div className="px-4 mb-6">
        <h1 className="text-lg font-bold text-foreground">S.F.C.P.C</h1>
        <p className="text-xs text-muted-foreground">Gestão de Estoque</p>
      </div>
      <nav className="flex-1 px-2 space-y-1">
        {navItems.map(({ to, icon: Icon, label }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 px-3 py-2 rounded-md text-sm transition-colors',
                isActive
                  ? 'bg-primary text-primary-foreground font-medium'
                  : 'text-muted-foreground hover:bg-accent hover:text-foreground'
              )
            }
          >
            <Icon size={16} />
            {label}
          </NavLink>
        ))}
      </nav>
    </aside>
  );
}
