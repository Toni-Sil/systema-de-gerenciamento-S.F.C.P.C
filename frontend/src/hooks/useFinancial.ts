import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';

export interface FinancialSummary {
  period: string;
  revenue: number;
  costs: number;
  profit: number;
  roi: number;
  monthly_breakdown: { month: string; revenue: number; cost: number }[];
}

export const useFinancialSummary = (period = 'monthly') =>
  useQuery<FinancialSummary>({
    queryKey: ['financial', period],
    queryFn: async () => (await api.get(`/api/v1/financial/summary?period=${period}`)).data,
    staleTime: 1000 * 60 * 5, // 5 min
  });
