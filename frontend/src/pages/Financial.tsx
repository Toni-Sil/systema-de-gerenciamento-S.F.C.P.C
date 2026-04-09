import { useQuery } from '@tanstack/react-query';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { api } from '@/lib/api';
import { 
  TrendingUp, 
  Wallet, 
  ArrowUpRight, 
  ArrowDownRight, 
  Receipt,
  PieChart as PieChartIcon,
  Activity,
  DollarSign
} from 'lucide-react';
import { 
  BarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer, 
  Legend,
  PieChart,
  Pie,
  Cell
} from 'recharts';
import { formatCurrency } from '@/lib/utils';
import { InvoiceUpload } from '@/components/InvoiceUpload';

const COLORS = ['#6366f1', '#f43f5e', '#fbbf24', '#22c55e', '#a855f7'];

export default function Financial() {
  const { data, isLoading } = useQuery({
    queryKey: ['financial-summary'],
    queryFn: () => api.get('/api/v1/financial/summary'),
  });

  const stats = [
    { 
      label: 'Valor em Estoque', 
      value: formatCurrency(data?.total_assets ?? 0), 
      icon: <Wallet className="text-indigo-400" />,
      trend: '+2.4%',
      isUp: true,
      description: 'Custo total de aquisição'
    },
    { 
      label: 'Receita Potencial', 
      value: formatCurrency(data?.potential_revenue ?? 0), 
      icon: <TrendingUp className="text-green-400" />,
      trend: '+5.1%',
      isUp: true,
      description: 'Valor estimado de venda'
    },
    { 
      label: 'Despesas Totais', 
      value: formatCurrency(data?.total_expenses ?? 0), 
      icon: <Receipt className="text-rose-400" />,
      trend: '-1.2%',
      isUp: false,
      description: 'Gastos gerais registrados'
    },
    { 
      label: 'Margem Bruta Est.', 
      value: formatCurrency(data?.gross_margin_estimate ?? 0), 
      icon: <DollarSign className="text-amber-400" />,
      trend: '+0.8%',
      isUp: true,
      description: 'Lucro flutuante do inventário'
    },
  ];

  const pieData = data ? Object.entries(data.expenses_by_category).map(([name, value]) => ({ name, value })) : [];

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight gradient-text">Centro Financeiro</h1>
          <p className="text-muted-foreground text-sm mt-1">Análise de ROI e saúde patrimonial (Gold Layer).</p>
        </div>
        <InvoiceUpload />
      </div>

      {/* KPI Row */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((stat, i) => (
          <Card key={i} className="border-white/10 bg-zinc-950/50 backdrop-blur-xl overflow-hidden group hover:border-white/20 transition-all">
            <CardContent className="p-6">
              <div className="flex items-center justify-between mb-4">
                 <div className="p-2 rounded-xl bg-white/5 border border-white/5">
                    {stat.icon}
                 </div>
                 <div className={`flex items-center gap-1 text-[10px] font-bold ${stat.isUp ? 'text-green-400' : 'text-rose-400'}`}>
                    {stat.isUp ? <ArrowUpRight size={12} /> : <ArrowDownRight size={12} />}
                    {stat.trend}
                 </div>
              </div>
              <p className="text-[10px] font-bold text-white/40 uppercase tracking-widest">{stat.label}</p>
              <h3 className="text-2xl font-bold mt-1">{isLoading ? '...' : stat.value}</h3>
              <p className="text-[10px] text-muted-foreground mt-2">{stat.description}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Main Chart */}
        <Card className="lg:col-span-2 border-white/10 bg-zinc-950/50 backdrop-blur-xl overflow-hidden shadow-2xl">
          <CardHeader>
            <div className="flex items-center gap-2">
               <Activity className="text-indigo-400" size={18} />
               <CardTitle className="text-lg">Fluxo de Valor Mensal</CardTitle>
            </div>
            <CardDescription>Comparativo entre entrada de receita e custos de operação.</CardDescription>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <div className="h-[300px] flex items-center justify-center text-muted-foreground">Calculando tendência...</div>
            ) : (
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={data?.monthly_breakdown ?? []}>
                  <CartesianGrid strokeDasharray="3 3" className="stroke-white/5" vertical={false} />
                  <XAxis dataKey="month" className="text-[10px]" axisLine={false} tickLine={false} />
                  <YAxis className="text-[10px]" axisLine={false} tickLine={false} tickFormatter={(v) => `R$${(v/1000).toFixed(0)}k`} />
                  <Tooltip 
                    contentStyle={{ backgroundColor: '#09090b', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '12px' }}
                    itemStyle={{ fontSize: '12px' }}
                  />
                  <Legend iconType="circle" wrapperStyle={{ fontSize: '10px', paddingTop: '20px' }} />
                  <Bar dataKey="revenue" name="Receita" fill="#6366f1" radius={[6, 6, 0, 0]} />
                  <Bar dataKey="cost" name="Custo" fill="#f43f5e" radius={[6, 6, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </CardContent>
        </Card>

        {/* Categories Pie */}
        <Card className="border-white/10 bg-zinc-950/50 backdrop-blur-xl overflow-hidden shadow-2xl">
          <CardHeader>
            <div className="flex items-center gap-2">
               <PieChartIcon className="text-purple-400" size={18} />
               <CardTitle className="text-lg">Distribuição de Gastos</CardTitle>
            </div>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <div className="h-[300px] flex items-center justify-center">...</div>
            ) : (
              <div className="flex flex-col items-center">
                <ResponsiveContainer width="100%" height={240}>
                  <PieChart>
                    <Pie
                      data={pieData}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={80}
                      paddingAngle={5}
                      dataKey="value"
                    >
                      {pieData.map((_, index) => (
                        <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
                <div className="mt-4 grid grid-cols-2 gap-x-8 gap-y-2 w-full">
                  {pieData.map((item, i) => (
                    <div key={i} className="flex items-center gap-2">
                       <div className="h-2 w-2 rounded-full" style={{ backgroundColor: COLORS[i % COLORS.length] }} />
                       <span className="text-[10px] text-white/60 truncate">{item.name}</span>
                       <span className="text-[10px] font-bold ml-auto">{formatCurrency(item.value)}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
