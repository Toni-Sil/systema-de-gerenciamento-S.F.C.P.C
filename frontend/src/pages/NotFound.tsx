import { Link } from 'react-router-dom';

export default function NotFound() {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen gap-4">
      <h1 className="text-6xl font-bold text-muted-foreground">404</h1>
      <p className="text-muted-foreground">Página não encontrada</p>
      <Link to="/dashboard" className="text-primary hover:underline text-sm">Voltar ao Dashboard</Link>
    </div>
  );
}
