import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatCurrency(value: number, locale = 'pt-BR', currency = 'BRL'): string {
  return new Intl.NumberFormat(locale, { style: 'currency', currency }).format(value);
}

export function formatDate(date: string | Date, locale = 'pt-BR'): string {
  return new Intl.DateTimeFormat(locale, { dateStyle: 'short', timeStyle: 'short' }).format(
    new Date(date)
  );
}

export function formatPercent(value: number): string {
  return `${(value * 100).toFixed(1)}%`;
}

export function getAbcColor(cls: 'A' | 'B' | 'C' | undefined): string {
  const map = { A: 'text-green-600 bg-green-50', B: 'text-yellow-600 bg-yellow-50', C: 'text-red-600 bg-red-50' };
  return map[cls ?? 'C'];
}
