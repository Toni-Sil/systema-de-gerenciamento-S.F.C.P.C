import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Package, TrendingDown, DollarSign, ArrowLeftRight } from 'lucide-react';
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from 'recharts';
import { useDashboard } from '@/hooks/useDashboard';
import { formatCurrency } from '@/lib/utils';
import { AIInsightCard } from '@/components/AIInsightCard';

const MOCK_TREND = [
  { date: 'Jan', value: 42000 },
  { date: 'Fev', value: 38000 },
  { date: 'Mar', value: 51000 },
  { date: 'Abr', value: 47000 },
  { date: 'Mai', value: 53000 },
  { date: 'Jun', value: 61000 },
];

const ABC_COLORS = ['#22c55e', '#eab308', '#ef4444'];

export default function Dashboard() {
  const { data, isLoading } = useDashboard();

  const kpis = [
    {
      title: 'Total de Produtos',
      value: isLoading ? '...' : data?.total_products ?? 0,
      icon: Package,
      badge: 'Ativo',
      badgeVariant: 'success' as const,
    },
    {
      title: 'Estoque Baixo',
      value: isLoading ? '...' : data?.low_stock_count ?? 0,
      icon: TrendingDown,
      badge: 'Atenção',
      badgeVariant: 'warning' as const,
    },
    {
      title: 'Valor Total',
      value: isLoading ? '...' : formatCurrency(data?.total_stock_value ?? 0),
      icon: DollarSign,
      badge: 'Em estoque',
      badgeVariant: 'default' as const,
    },
    {
      title: 'Movimentos Hoje',
      value: isLoading ? '...' : data?.movements_today ?? 0,
      icon: ArrowLeftRight,
      badge: 'Hoje',
      badgeVariant: 'secondary' as const,
    },
  ];

  const abcData = data?.abc_breakdown ?? [
    { class: 'A', count: 12, value: 75000 },
    { class: 'B', count: 28, value: 18000 },
    { class: 'C', count: 60, value: 7000 },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Dashboard</h1>
        <p className="text-muted-foreground text-sm">Visão geral do sistema</p>
      </div>

      <AIInsightCard />

      {/* KPIs */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {kpis.map(({ title, value, icon: Icon, badge, badgeVariant }) => (
          <Card key={title}>
            <CardHeader className="pb-2">
              <div className="flex items-center justify-between">
                <CardTitle className="text-sm font-medium text-muted-foreground">{title}</CardTitle>
                <Icon size={16} className="text-muted-foreground" />
              </div>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-bold">{value}</p>
              <Badge variant={badgeVariant} className="mt-2">{badge}</Badge>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Tendência de Valor de Estoque</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={220}>
              <AreaChart data={data?.stock_trend ?? MOCK_TREND}>
                <defs>
                  <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#6366f1" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#6366f1" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" className="stroke-border" />
                <XAxis dataKey="date" className="text-xs" />
                <YAxis className="text-xs" tickFormatter={(v) => `R$${(v/1000).toFixed(0)}k`} />
                <Tooltip formatter={(v: number) => formatCurrency(v)} />
                <Area type="monotone" dataKey="value" stroke="#6366f1" fill="url(#colorValue)" strokeWidth={2} />
              </AreaChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Análise ABC</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-col items-center">
            <ResponsiveContainer width="100%" height={180}>
              <PieChart>
                <Pie data={abcData} dataKey="count" nameKey="class" cx="50%" cy="50%" outerRadius={70} label={({ class: c }) => c}>
                  {abcData.map((_, i) => <Cell key={i} fill={ABC_COLORS[i % 3]} />)}
                </Pie>
                <Tooltip formatter={(v: number, name: string) => [`${v} itens`, `Classe ${name}`]} />
              </PieChart>
            </ResponsiveContainer>
            <div className="flex gap-4 mt-2">
              {['A', 'B', 'C'].map((c, i) => (
                <span key={c} className="flex items-center gap-1 text-xs">
                  <span className="w-3 h-3 rounded-full inline-block" style={{ background: ABC_COLORS[i] }} />
                  Classe {c}
                </span>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
