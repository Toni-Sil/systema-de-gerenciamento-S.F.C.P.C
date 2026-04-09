import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Package, DollarSign, ArrowLeftRight, Activity, Flame } from 'lucide-react';
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell,
} from 'recharts';
import { useDashboard } from '@/hooks/useDashboard';
import { formatCurrency } from '@/lib/utils';
import { AIInsightCard } from '@/components/AIInsightCard';
import { PageTransition, StaggerList, StaggerItem, AnimatedCounter } from '@/components/motion';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';

const MOCK_TREND = [
  { date: 'Out', value: 42000 },
  { date: 'Nov', value: 38000 },
  { date: 'Dez', value: 51000 },
  { date: 'Jan', value: 47000 },
  { date: 'Fev', value: 53000 },
  { date: 'Mar', value: 61000 },
];
const ABC_COLORS = ['#7c3aed', '#a78bfa', '#ddd6fe'];

export default function Dashboard() {
  const { data, isLoading } = useDashboard();
  const { data: kpis } = useQuery({
    queryKey: ['analytics-kpis'],
    queryFn: () => api.get('/api/v1/analytics/kpis'),
  });

  const kpiCards = [
    {
      title: 'Total de Produtos',
      value: data?.total_products ?? 0,
      icon: Package,
      badge: 'Ativo',
      badgeVariant: 'success' as const,
      color: 'text-indigo-400',
      bg: 'bg-indigo-500/10',
    },
    {
      title: 'Estoque Crítico',
      value: kpis?.critical_items ?? 0,
      icon: Flame,
      badge: 'Urgente',
      badgeVariant: 'destructive' as const,
      color: 'text-red-400',
      bg: 'bg-red-500/10',
    },
    {
      title: 'Valor Total',
      rawValue: data?.total_stock_value ?? 0,
      isMonetary: true,
      icon: DollarSign,
      badge: 'Em estoque',
      badgeVariant: 'default' as const,
      color: 'text-green-400',
      bg: 'bg-green-500/10',
    },
    {
      title: 'Movimentos Hoje',
      value: data?.movements_today ?? 0,
      icon: ArrowLeftRight,
      badge: 'Hoje',
      badgeVariant: 'secondary' as const,
      color: 'text-purple-400',
      bg: 'bg-purple-500/10',
    },
  ];

  const abcData = data?.abc_breakdown ?? [
    { class: 'A', count: 12, value: 75000 },
    { class: 'B', count: 28, value: 18000 },
    { class: 'C', count: 60, value: 7000 },
  ];

  return (
    <PageTransition>
      <div className="space-y-8">
        {/* Header */}
        <SlideInHeader />

        {/* AI Insight */}
        <AIInsightCard />

        {/* KPI Cards — stagger in */}
        <StaggerList className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {kpiCards.map(({ title, value, rawValue, isMonetary, icon: Icon, badge, badgeVariant, color, bg }) => (
            <StaggerItem key={title}>
              <Card className="border-border/50 hover-lift glass relative overflow-hidden group">
                {/* Accent line top */}
                <div className={`absolute inset-x-0 top-0 h-0.5 bg-gradient-to-r from-transparent ${bg.replace('bg-', 'via-').replace('/10', '')} to-transparent opacity-0 group-hover:opacity-100 transition-opacity`} />
                <CardHeader className="pb-2">
                  <div className="flex items-center justify-between">
                    <CardTitle className="text-sm font-medium text-muted-foreground">{title}</CardTitle>
                    <div className={`h-8 w-8 rounded-xl ${bg} ${color} flex items-center justify-center`}>
                      <Icon size={15} />
                    </div>
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold tracking-tight">
                    {isLoading ? (
                      <div className="h-8 w-20 shimmer rounded-lg" />
                    ) : isMonetary ? (
                      formatCurrency(rawValue ?? 0)
                    ) : (
                      <AnimatedCounter value={value ?? 0} />
                    )}
                  </div>
                  <Badge variant={badgeVariant} className="mt-2 text-[10px]">{badge}</Badge>
                </CardContent>
              </Card>
            </StaggerItem>
          ))}
        </StaggerList>

        {/* Charts */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <Card className="lg:col-span-2 border-border/50 glass hover-lift">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-base">
                <Activity size={16} className="text-indigo-400" />
                Tendência de Valor de Estoque
              </CardTitle>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={220}>
                <AreaChart data={data?.stock_trend ?? MOCK_TREND}>
                  <defs>
                    <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%"  stopColor="hsl(251 86% 62%)" stopOpacity={0.25} />
                      <stop offset="95%" stopColor="hsl(251 86% 62%)" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" className="stroke-border" />
                  <XAxis dataKey="date" tick={{ fontSize: 10 }} />
                  <YAxis tickFormatter={(v) => `R$${(v / 1000).toFixed(0)}k`} tick={{ fontSize: 10 }} />
                  <Tooltip
                    formatter={(v: number) => formatCurrency(v)}
                    contentStyle={{
                      background: 'hsl(0 0% 6%)',
                      border: '1px solid hsl(0 0% 13%)',
                      borderRadius: '12px',
                      fontSize: '12px',
                    }}
                  />
                  <Area
                    type="monotone"
                    dataKey="value"
                    stroke="hsl(251 86% 62%)"
                    fill="url(#colorValue)"
                    strokeWidth={2.5}
                    dot={false}
                    activeDot={{ r: 5, fill: 'hsl(251 86% 62%)', strokeWidth: 0 }}
                  />
                </AreaChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>

          {/* ABC Pie */}
          <Card className="border-border/50 glass hover-lift">
            <CardHeader>
              <CardTitle className="text-base">Análise ABC</CardTitle>
            </CardHeader>
            <CardContent className="flex flex-col items-center">
              <ResponsiveContainer width="100%" height={180}>
                <PieChart>
                  <Pie
                    data={abcData}
                    dataKey="count"
                    nameKey="class"
                    cx="50%"
                    cy="50%"
                    outerRadius={70}
                    innerRadius={40}
                    label={({ class: c }) => c}
                    strokeWidth={0}
                  >
                    {abcData.map((_, i) => (
                      <Cell key={i} fill={ABC_COLORS[i % 3]} />
                    ))}
                  </Pie>
                  <Tooltip
                    formatter={(v: number, name: string) => [`${v} itens`, `Classe ${name}`]}
                    contentStyle={{
                      background: 'hsl(0 0% 6%)',
                      border: '1px solid hsl(0 0% 13%)',
                      borderRadius: '12px',
                      fontSize: '12px',
                    }}
                  />
                </PieChart>
              </ResponsiveContainer>
              <div className="flex gap-4 mt-2">
                {['A', 'B', 'C'].map((c, i) => (
                  <span key={c} className="flex items-center gap-1.5 text-xs text-muted-foreground">
                    <span className="w-2.5 h-2.5 rounded-full inline-block" style={{ background: ABC_COLORS[i] }} />
                    Classe {c}
                  </span>
                ))}
              </div>
            </CardContent>
          </Card>
        </div>

        {/* External OS Integration Status */}
        <ExternalOSWidget />
      </div>
    </PageTransition>
  );
}

function SlideInHeader() {
  return (
    <div>
      <h1 className="text-3xl font-bold tracking-tight gradient-text">Gestão de Sofás para Caminhões</h1>
      <p className="text-muted-foreground text-sm mt-1">Inteligência logística e conforto para o transporte rodoviário</p>
    </div>
  );
}

function ExternalOSWidget() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['external-orders'],
    queryFn: () => api.get('/api/v1/external/orders'),
    refetchInterval: 60000, // Sync every minute
  });

  const orders = data?.status === 'success' ? data.data : [];

  return (
    <Card className="border-border/50 glass overflow-hidden">
      <CardHeader className="bg-white/[0.02] border-b border-border/50">
        <div className="flex items-center justify-between">
          <CardTitle className="text-sm font-semibold flex items-center gap-2">
            <Activity className="text-orange-400" size={16} />
            Sistema Externo de Ordens de Serviço
          </CardTitle>
          <Badge variant="outline" className="text-[10px] bg-orange-500/5 text-orange-400 border-orange-500/20">
            Sincronização Ativa
          </Badge>
        </div>
      </CardHeader>
      <CardContent className="p-0">
        {isLoading ? (
          <div className="p-8 flex justify-center"><div className="h-6 w-6 border-2 border-orange-500 border-t-transparent rounded-full animate-spin" /></div>
        ) : error || data?.status === 'error' ? (
          <div className="p-8 text-center text-xs text-muted-foreground">
            Aguardando configuração de integração OS nas configurações.
          </div>
        ) : orders.length === 0 ? (
          <div className="p-8 text-center text-xs text-muted-foreground">Nenhuma ordem aberta no sistema externo.</div>
        ) : (
          <div className="divide-y divide-border/50">
            {orders.slice(0, 5).map((order: any) => (
              <div key={order.id} className="p-4 flex items-center justify-between hover:bg-white/[0.01] transition-colors">
                <div className="flex flex-col gap-0.5">
                  <span className="text-xs font-bold text-foreground">OS #{order.id}</span>
                  <span className="text-[10px] text-muted-foreground line-clamp-1">{order.description}</span>
                </div>
                <div className="flex items-center gap-3">
                  <span className="text-[10px] font-medium text-orange-400 capitalize bg-orange-400/10 px-2 py-0.5 rounded-full">{order.status}</span>
                  <div className="text-[10px] text-muted-foreground text-right">
                    {order.fabric && <span className="block italic opacity-70">{order.fabric}</span>}
                  </div>
                </div>
              </div>
            ))}
            {orders.length > 5 && (
              <div className="p-3 text-center text-[10px] text-muted-foreground bg-white/[0.01]">
                Mais {orders.length - 5} ordens em andamento no sistema de OS.
              </div>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
