import { Menu, Bell } from 'lucide-react';

export function TopNavbar({ onToggleSidebar }: { onToggleSidebar: () => void }) {
  return (
    <header className="h-14 border-b border-border bg-card px-4 flex items-center justify-between shrink-0">
      <button
        onClick={onToggleSidebar}
        className="p-2 rounded-md hover:bg-accent transition-colors"
        aria-label="Toggle sidebar"
      >
        <Menu size={20} />
      </button>
      <div className="flex items-center gap-3">
        <button className="p-2 rounded-md hover:bg-accent transition-colors" aria-label="Alertas">
          <Bell size={20} />
        </button>
        <div className="w-8 h-8 rounded-full bg-primary flex items-center justify-center text-primary-foreground text-sm font-bold">
          T
        </div>
      </div>
    </header>
  );
}
