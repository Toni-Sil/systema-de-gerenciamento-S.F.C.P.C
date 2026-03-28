import { QueryClientProvider } from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'sonner';
import { queryClient } from '@/lib/queryClient';
import { AppLayout } from '@/components/AppLayout';
import Dashboard from '@/pages/Dashboard';
import Products from '@/pages/Products';
import StockBalance from '@/pages/StockBalance';
import Movements from '@/pages/Movements';
import Financial from '@/pages/Financial';
import Reports from '@/pages/Reports';
import Alerts from '@/pages/Alerts';
import Settings from '@/pages/Settings';
import NotFound from '@/pages/NotFound';

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<AppLayout />}>
            <Route index element={<Navigate to="/dashboard" replace />} />
            <Route path="dashboard" element={<Dashboard />} />
            <Route path="products" element={<Products />} />
            <Route path="stock" element={<StockBalance />} />
            <Route path="movements" element={<Movements />} />
            <Route path="financial" element={<Financial />} />
            <Route path="reports" element={<Reports />} />
            <Route path="alerts" element={<Alerts />} />
            <Route path="settings" element={<Settings />} />
          </Route>
          <Route path="*" element={<NotFound />} />
        </Routes>
      </BrowserRouter>
      <Toaster richColors position="top-right" />
      {import.meta.env.DEV && <ReactQueryDevtools initialIsOpen={false} />}
    </QueryClientProvider>
  );
}
