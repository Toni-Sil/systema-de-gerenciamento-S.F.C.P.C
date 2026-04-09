import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "@/hooks/use-auth";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { useToast } from "@/hooks/use-toast";

export default function Login() {
  const navigate = useNavigate();
  const { login } = useAuth();
  const { toast } = useToast();
  const [loading, setLoading] = useState(false);
  const [form, setForm] = useState({
    email: "",
    password: "",
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.email || !form.password) {
      toast({ title: "Preencha todos os campos", variant: "destructive" });
      return;
    }
    setLoading(true);
    try {
      await login(form);
      navigate("/dashboard");
    } catch (err) {
      toast({
        title: "Erro ao entrar",
        description: err instanceof Error ? err.message : "Credenciais inválidas",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-[100dvh] flex items-center justify-center bg-background px-4">
      <Card className="w-full max-w-sm border-none bg-zinc-950/50 backdrop-blur-xl shadow-2xl overflow-hidden relative noise">
        <CardHeader className="text-center pt-8">
          <div className="mx-auto w-24 h-24 mb-4 rounded-full border-2 border-primary p-2 bg-white shadow-xl float flex items-center justify-center overflow-hidden">
            <img src="/assets/logo.png" alt="Logo" className="w-full h-full object-contain drop-shadow-sm rounded-full" />
          </div>
          <CardTitle className="text-3xl font-black tracking-tighter text-white drop-shadow-md">S.F.C.P.C</CardTitle>
          <CardDescription className="text-primary font-bold uppercase tracking-widest text-[10px]">Gestão de Sofás para Caminhões</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <Label htmlFor="email">E-mail</Label>
              <Input
                id="email"
                type="email"
                placeholder="seu@email.com"
                className="bg-white/5 border-white/10"
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
              />
            </div>
            <div>
              <div className="flex items-center justify-between">
                <Label htmlFor="password">Senha</Label>
                <button type="button" className="text-[10px] text-indigo-400 hover:text-indigo-300">Esqueceu a senha?</button>
              </div>
              <Input
                id="password"
                type="password"
                placeholder="••••••••"
                className="bg-white/5 border-white/10"
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
              />
            </div>
            <Button type="submit" className="w-full h-11 rounded-xl bg-indigo-600 hover:bg-indigo-500 shadow-lg shadow-indigo-500/20" disabled={loading}>
              {loading ? "Autenticando..." : "Entrar no Sistema"}
            </Button>
            <div className="text-center text-sm pt-2">
               Ainda não tem acesso? <Link to="/register" className="text-indigo-400 font-medium hover:underline">Cadastrar Empresa</Link>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
