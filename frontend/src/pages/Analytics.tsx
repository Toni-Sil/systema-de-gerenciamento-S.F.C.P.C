import { useQuery } from '@tanstack/react-query';
import {
  ResponsiveContainer, AreaChart, Area, BarChart, Bar,
  XAxis, YAxis, Tooltip, CartesianGrid, Cell,
} from 'recharts';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { api, exportFinancialReport, exportInventoryReport, exportMovementsReport } from '@/lib/api';
import { formatCurrency } from '@/lib/utils';
import { AIInsightCard } from '@/components/AIInsightCard';
import {
  TrendingUp, TrendingDown, ShieldCheck,
  PackageX, Flame, Activity, Download,
} from 'lucide-react';

interface StockHealth {
  product_id: string;
  code: string;
  description: string;
  category: string;
  current_balance: number;
  min_stock: number;
  avg_daily_consumption: number;
  days_until_stockout: number | null;
  risk_level: 'critical' | 'warning' | 'healthy' | 'stable';
  abc_class: 'A' | 'B' | 'C';
  total_exit_30d: number;
}

interface KPIs {
  total_products: number;
  critical_items: number;
  warning_items: number;
  monthly_expense: number;
  health_score: number;
}

const RISK_CONFIG = {
  critical: { label: 'Crítico', color: '#ef4444', bg: 'bg-red-500/10', text: 'text-red-500', border: 'border-red-500/20' },
  warning:  { label: 'Atenção', color: '#f59e0b', bg: 'bg-amber-500/10', text: 'text-amber-500', border: 'border-amber-500/20' },
  healthy:  { label: 'Saudável', color: '#22c55e', bg: 'bg-green-500/10', text: 'text-green-500', border: 'border-green-500/20' },
  stable:   { label: 'Estável', color: '#6366f1', bg: 'bg-indigo-500/10', text: 'text-indigo-400', border: 'border-indigo-500/20' },
};

export default function Analytics() {
  const { data: health, isLoading: healthLoading } = useQuery<StockHealth[]>({
    queryKey: ['stock-health'],
    queryFn: () => api.get('/api/v1/analytics/stock-health'),
  });


  const { data: kpis } = useQuery<KPIs>({
    queryKey: ['analytics-kpis'],
    queryFn: () => api.get('/api/v1/analytics/kpis'),
  });

  const { data: finance, isLoading: finLoading } = useQuery<any>({
    queryKey: ['financial-performance'],
    queryFn: () => api.get('/api/v1/analytics/financial-performance'),
  });

  const criticalItems = health?.filter(h => h.risk_level === 'critical') ?? [];

  const handleExport = async () => {
    try {
      const blob = await exportFinancialReport();
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', `relatorio_financeiro_${new Date().toISOString().split('T')[0]}.csv`);
      document.body.appendChild(link);
      link.click();
      link.remove();
    } catch (error) {
      console.error("Export error:", error);
    }
  };

  const handleExportInventory = async () => {
    try {
      const blob = await exportInventoryReport();
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', `estoque_atual_${new Date().toISOString().split('T')[0]}.csv`);
      document.body.appendChild(link);
      link.click();
      link.remove();
    } catch (error) {
      console.error("Inventory export error:", error);
    }
  };

  const handleExportMovements = async () => {
    try {
      const blob = await exportMovementsReport();
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', `historico_movimentacoes_${new Date().toISOString().split('T')[0]}.csv`);
      document.body.appendChild(link);
      link.click();
      link.remove();
    } catch (error) {
      console.error("Movements export error:", error);
    }
  };

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">

      {/* Header */}
      <div className="flex flex-row items-center justify-between">
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-3">
            <Activity className="h-7 w-7 text-indigo-400" />
            <h1 className="text-3xl font-bold tracking-tight">Inteligência Preditiva</h1>
          </div>
          <p className="text-muted-foreground">Análise de saúde do estoque e previsões de ruptura em tempo real.</p>
        </div>
        <div className="flex gap-2">
          <button 
            onClick={handleExportInventory}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-green-500/10 border border-green-500/20 hover:bg-green-500/20 transition-all text-xs font-medium text-green-400"
          >
            <Download size={14} />
            Estoque (CSV)
          </button>
          <button 
            onClick={handleExportMovements}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-indigo-500/10 border border-indigo-500/20 hover:bg-indigo-500/20 transition-all text-xs font-medium text-indigo-400"
          >
            <Download size={14} />
            Histórico (CSV)
          </button>
          <button 
            onClick={handleExport}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10 transition-all text-xs font-medium"
          >
            <Download size={14} />
            Financeiro (CSV)
          </button>
        </div>
      </div>

      {/* AI Insight */}
      <AIInsightCard />

      {/* Executive KPIs */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          {
            label: 'Margem Bruta',
            value: finance ? formatCurrency(finance.gross_margin_estimate) : '...',
            icon: TrendingUp,
            color: 'text-indigo-400',
            bg: 'bg-indigo-500/10',
            sub: 'lucro bruto estimado',
          },
          {
            label: 'Patrimônio em Estoque',
            value: finance ? formatCurrency(finance.total_assets) : '...',
            icon: ShieldCheck,
            color: 'text-green-400',
            bg: 'bg-green-500/10',
            sub: 'valor de compra total',
          },
          {
            label: 'Rupturas',
            value: kpis?.critical_items ?? '...',
            icon: Flame,
            color: 'text-red-400',
            bg: 'bg-red-500/10',
            sub: 'itens esgotados',
          },
          {
            label: 'Gasto Mensal',
            value: kpis ? formatCurrency(kpis.monthly_expense) : '...',
            icon: TrendingDown,
            color: 'text-purple-400',
            bg: 'bg-purple-500/10',
            sub: 'despesas este mês',
          },
        ].map(({ label, value, icon: Icon, color, bg, sub }) => (
          <Card key={label} className="border-white/5 bg-zinc-950/50">
            <CardContent className="p-5">
              <div className={`h-10 w-10 rounded-xl ${bg} ${color} flex items-center justify-center mb-4`}>
                <Icon size={20} />
              </div>
              <p className="text-2xl font-bold tracking-tight mb-1">{value}</p>
              <p className="text-[10px] uppercase tracking-wider text-white/40 font-medium">{label}</p>
              <p className="text-xs text-muted-foreground mt-1">{sub}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Critical alerts strip */}
      {criticalItems.length > 0 && (
        <div className="flex flex-col gap-2">
          <p className="text-xs uppercase font-bold tracking-widest text-red-500 flex items-center gap-2">
            <Flame size={12} /> Ruptura Iminente — Ação Imediata Necessária
          </p>
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
            {criticalItems.map(item => (
              <div key={item.product_id}
                className="flex items-center gap-4 p-4 rounded-2xl bg-red-500/5 border border-red-500/20"
              >
                <PackageX className="h-8 w-8 text-red-500 flex-shrink-0" />
                <div className="min-w-0">
                  <p className="font-semibold truncate">{item.description}</p>
                  <p className="text-xs text-red-400">
                    {item.days_until_stockout !== null
                      ? `Acaba em ~${item.days_until_stockout} dias`
                      : 'Saldo esgotado'} · Saldo: {item.current_balance}
                  </p>
                </div>
                <Badge className="ml-auto flex-shrink-0 bg-red-500/20 text-red-400 border-red-500/30">
                  {item.abc_class}
                </Badge>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Charts row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Financial Performance Chart */}
        <Card className="border-white/5 bg-zinc-950/50">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-base">
              <TrendingUp size={16} className="text-indigo-400" /> Lucratividade (Receita vs Custo)
            </CardTitle>
          </CardHeader>
          <CardContent>
            {finLoading ? (
              <div className="h-52 flex items-center justify-center text-muted-foreground animate-pulse">Analisando histórico...</div>
            ) : (
              <ResponsiveContainer width="100%" height={220}>
                <AreaChart data={finance?.monthly_breakdown ?? []}>
                  <defs>
                    <linearGradient id="revenueGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%"  stopColor="#22c55e" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#22c55e" stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="costGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%"  stopColor="#ef4444" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#ef4444" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" className="stroke-white/5" />
                  <XAxis dataKey="month" tick={{ fontSize: 10 }} />
                  <YAxis tickFormatter={(v) => `R$${(v/1000).toFixed(0)}k`} tick={{ fontSize: 10 }} />
                  <Tooltip formatter={(v: number) => formatCurrency(v)} />
                  <Area type="monotone" dataKey="revenue" name="Receita" stroke="#22c55e" fill="url(#revenueGrad)" strokeWidth={2} />
                  <Area type="monotone" dataKey="cost" name="Custo" stroke="#ef4444" fill="url(#costGrad)" strokeWidth={2} />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </CardContent>
        </Card>

        {/* Top consumed products */}
        <Card className="border-white/5 bg-zinc-950/50">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-base">
              <Activity size={16} className="text-indigo-400" /> Consumo Top 5 (30 dias)
            </CardTitle>
          </CardHeader>
          <CardContent>
            {healthLoading ? (
              <div className="h-52 flex items-center justify-center text-muted-foreground animate-pulse">Calculando...</div>
            ) : (
              <ResponsiveContainer width="100%" height={220}>
                <BarChart
                  layout="vertical"
                  data={[...(health ?? [])]
                    .sort((a, b) => b.total_exit_30d - a.total_exit_30d)
                    .slice(0, 5)
                    .map(h => ({ name: h.description.substring(0, 20), saidas: h.total_exit_30d }))}
                >
                  <CartesianGrid strokeDasharray="3 3" className="stroke-white/5" />
                  <XAxis type="number" tick={{ fontSize: 10 }} />
                  <YAxis dataKey="name" type="category" width={120} tick={{ fontSize: 10 }} />
                  <Tooltip />
                  <Bar dataKey="saidas" name="Saídas" radius={[0, 6, 6, 0]}>
                    {(health ?? []).slice(0, 5).map((_, i) => (
                      <Cell key={i} fill={`hsl(${250 + i * 20}, 70%, 60%)`} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Full health table */}
      <Card className="border-white/5 bg-zinc-950/50">
        <CardHeader>
          <CardTitle className="text-base">Inventário Completo — Análise ABC & Previsão de Ruptura</CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-white/5 text-left">
                  {['Produto', 'Saldo', 'Consumo/dia', 'Ruptura em', 'Classe', 'Status'].map(h => (
                    <th key={h} className="px-4 py-3 text-xs uppercase tracking-wider text-white/40 font-bold">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {(health ?? []).map((item, i) => {
                  const cfg = RISK_CONFIG[item.risk_level];
                  return (
                    <tr key={item.product_id} className={`border-b border-white/5 transition-colors hover:bg-white/[0.03] ${i % 2 === 0 ? '' : 'bg-white/[0.02]'}`}>
                      <td className="px-4 py-3">
                        <p className="font-medium truncate max-w-[200px]">{item.description}</p>
                        <p className="text-[10px] text-muted-foreground">{item.code}</p>
                      </td>
                      <td className="px-4 py-3 font-mono">{item.current_balance}</td>
                      <td className="px-4 py-3 text-muted-foreground">{item.avg_daily_consumption}/dia</td>
                      <td className="px-4 py-3">
                        {item.days_until_stockout !== null
                          ? <span className={cfg.text}>{item.days_until_stockout} dias</span>
                          : <span className="text-muted-foreground">—</span>}
                      </td>
                      <td className="px-4 py-3">
                        <span className={`font-bold text-xs px-2 py-0.5 rounded-full ${
                          item.abc_class === 'A' ? 'bg-green-500/20 text-green-400' :
                          item.abc_class === 'B' ? 'bg-yellow-500/20 text-yellow-400' :
                          'bg-white/10 text-white/40'
                        }`}>{item.abc_class}</span>
                      </td>
                      <td className="px-4 py-3">
                        <Badge className={`${cfg.bg} ${cfg.text} ${cfg.border} border text-[10px]`}>
                          {cfg.label}
                        </Badge>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
