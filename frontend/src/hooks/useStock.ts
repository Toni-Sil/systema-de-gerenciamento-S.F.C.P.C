import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';

export interface Product {
  id: number;
  name: string;
  sku: string;
  quantity: number;
  min_quantity: number;
  unit_cost: number;
  category: string;
  abc_class?: 'A' | 'B' | 'C';
}

export interface StockMovement {
  id: number;
  product_id: number;
  product_name: string;
  type: 'IN' | 'OUT';
  quantity: number;
  created_at: string;
  note?: string;
}

// --- Products ---
export const useProducts = () =>
  useQuery<Product[]>({
    queryKey: ['products'],
    queryFn: async () => (await api.get('/api/v1/products')).data,
  });

export const useCreateProduct = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: Omit<Product, 'id'>) => api.post('/api/v1/products', data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['products'] }),
  });
};

export const useUpdateProduct = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...data }: Partial<Product> & { id: number }) =>
      api.patch(`/api/v1/products/${id}`, data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['products'] }),
  });
};

export const useDeleteProduct = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => api.delete(`/api/v1/products/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['products'] }),
  });
};

// --- Movements ---
export const useMovements = (limit = 50) =>
  useQuery<StockMovement[]>({
    queryKey: ['movements', limit],
    queryFn: async () => (await api.get(`/api/v1/movements?limit=${limit}`)).data,
    refetchInterval: 30000, // atualiza a cada 30s
  });

export const useCreateMovement = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: Omit<StockMovement, 'id' | 'created_at'>) =>
      api.post('/api/v1/movements', data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['movements'] });
      qc.invalidateQueries({ queryKey: ['products'] });
      qc.invalidateQueries({ queryKey: ['dashboard'] });
    },
  });
};
