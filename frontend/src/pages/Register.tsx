import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { useToast } from "@/hooks/use-toast";
import { api } from "@/lib/api";

export default function Register() {
  const navigate = useNavigate();
  const { toast } = useToast();
  const [loading, setLoading] = useState(false);
  const [form, setForm] = useState({
    company_name: "",
    username: "",
    email: "",
    password: "",
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.company_name || !form.username || !form.email || !form.password) {
      toast({ title: "Preencha todos os campos", variant: "destructive" });
      return;
    }
    setLoading(true);
    try {
      await api.post("/auth/signup", form);
      toast({ title: "Conta criada!", description: "Sua empresa foi registrada com sucesso." });
      navigate("/login");
    } catch (err) {
      toast({
        title: "Erro ao criar conta",
        description: err instanceof Error ? err.message : "Erro desconhecido",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-[100dvh] flex items-center justify-center bg-background px-4">
      <Card className="w-full max-w-sm border-none bg-zinc-950/50 backdrop-blur-xl shadow-2xl relative noise overflow-hidden">
        <CardHeader className="text-center pt-8">
          <div className="mx-auto w-20 h-20 mb-4 rounded-full border-2 border-primary p-2 bg-white shadow-xl float flex items-center justify-center overflow-hidden">
            <img src="/assets/logo.png" alt="Logo" className="w-full h-full object-contain drop-shadow-sm rounded-full" />
          </div>
          <CardTitle className="text-2xl font-black text-white">Começar Agora</CardTitle>
          <CardDescription className="text-primary font-bold uppercase tracking-widest text-[10px]">S.F.C.P.C — Gestão de Sofás para Caminhões</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <Label htmlFor="company_name">Nome da Empresa</Label>
              <Input
                id="company_name"
                placeholder="Ex: Minha Logística LTDA"
                value={form.company_name}
                onChange={(e) => setForm({ ...form, company_name: e.target.value })}
              />
            </div>
            <div>
              <Label htmlFor="username">Seu Nome de Usuário</Label>
              <Input
                id="username"
                placeholder="admin"
                value={form.username}
                onChange={(e) => setForm({ ...form, username: e.target.value })}
              />
            </div>
            <div>
              <Label htmlFor="email">E-mail Corporativo</Label>
              <Input
                id="email"
                type="email"
                placeholder="seu@email.com"
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
              />
            </div>
            <div>
              <Label htmlFor="password">Senha de Acesso</Label>
              <Input
                id="password"
                type="password"
                placeholder="mínimo 8 caracteres"
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
              />
            </div>
            <Button type="submit" className="w-full h-11 rounded-xl bg-indigo-600 hover:bg-indigo-500 shadow-lg shadow-indigo-500/20" disabled={loading}>
              {loading ? "Criando conta..." : "Criar Minha Empresa"}
            </Button>
            <div className="text-center text-sm">
               Já tem uma conta? <Link to="/login" className="text-indigo-400 hover:underline">Fazer Login</Link>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
