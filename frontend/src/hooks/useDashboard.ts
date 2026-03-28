import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';

export interface DashboardKPIs {
  total_products: number;
  low_stock_count: number;
  total_stock_value: number;
  movements_today: number;
  abc_breakdown: { class: string; count: number; value: number }[];
  stock_trend: { date: string; value: number }[];
}

export const useDashboard = () =>
  useQuery<DashboardKPIs>({
    queryKey: ['dashboard'],
    queryFn: async () => (await api.get('/api/v1/dashboard/kpis')).data,
    refetchInterval: 60000, // atualiza a cada 1 min
  });
