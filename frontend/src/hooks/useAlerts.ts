import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';

export interface Alert {
  id: number;
  type: 'LOW_STOCK' | 'EXPIRY' | 'REORDER' | 'ANOMALY';
  product_id?: number;
  product_name?: string;
  message: string;
  severity: 'INFO' | 'WARNING' | 'CRITICAL';
  read: boolean;
  created_at: string;
}

export const useAlerts = () =>
  useQuery<Alert[]>({
    queryKey: ['alerts'],
    queryFn: async () => (await api.get('/api/v1/alerts')).data,
    refetchInterval: 30000,
  });

export const useMarkAlertRead = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => api.patch(`/api/v1/alerts/${id}/read`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['alerts'] }),
  });
};
