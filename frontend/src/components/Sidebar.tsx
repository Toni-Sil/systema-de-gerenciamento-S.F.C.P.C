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
  X,
  ShieldAlert,
  BrainCircuit,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { AIMovementInput } from './AIMovementInput';

const navItems = [
  { to: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/products', icon: Package, label: 'Produtos' },
  { to: '/stock', icon: BarChart3, label: 'Estoque' },
  { to: '/movements', icon: ArrowLeftRight, label: 'Movimentações' },
  { to: '/financial', icon: DollarSign, label: 'Financeiro' },
  { to: '/analytics', icon: BrainCircuit, label: 'Análise Preditiva' },
  { to: '/governance', icon: ShieldAlert, label: 'Governança' },
  { to: '/reports', icon: FileText, label: 'Relatórios' },
  { to: '/alerts', icon: Bell, label: 'Alertas' },
  { to: '/settings', icon: Settings, label: 'Configurações' },
];

interface SidebarProps {
  open: boolean;
  setOpen: (open: boolean) => void;
}

export function Sidebar({ open, setOpen }: SidebarProps) {
  return (
    <>
      <aside 
        className={cn(
          "fixed inset-y-0 left-0 z-50 w-64 bg-card border-r border-border flex flex-col py-4 transition-transform duration-300 lg:static lg:translate-x-0 shrink-0",
          open ? "translate-x-0" : "-translate-x-full"
        )}
      >
        <div className="px-4 mb-6 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="h-12 w-12 rounded-full border-2 border-primary p-0.5 overflow-hidden bg-white shadow-sm">
                <img src="/assets/logo.png" alt="Logo" className="h-full w-full object-contain" />
            </div>
            <div>
              <h1 className="text-sm font-black text-foreground leading-none tracking-tight">S.F.C.P.C</h1>
              <p className="text-[10px] text-primary uppercase tracking-widest font-bold">Smart Logistics</p>
            </div>
          </div>
          <button 
            onClick={() => setOpen(false)}
            className="p-2 lg:hidden text-muted-foreground hover:text-foreground"
          >
            <X size={20} />
          </button>
        </div>

        <div className="px-4 mb-6">
           <AIMovementInput onDataExtracted={(data) => console.log('AI Data:', data)} variant="inline" />
        </div>

        <nav className="flex-1 px-2 space-y-1 overflow-y-auto">
          {navItems.map(({ to, icon: Icon, label }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                cn(
                  'flex items-center gap-3 px-3 py-2 rounded-xl text-sm transition-all duration-200',
                  isActive
                    ? 'bg-primary/10 text-primary font-semibold shadow-sm border border-primary/20'
                    : 'text-muted-foreground hover:bg-accent/50 hover:text-foreground'
                )
              }
            >
              <Icon size={16} />
              {label}
            </NavLink>
          ))}
        </nav>
      </aside>

      {/* Magic Floating Button for Mobile */}
      <div className="lg:hidden">
          <AIMovementInput onDataExtracted={(data) => console.log('AI Data:', data)} variant="floating" />
      </div>

    </>
  );
}


