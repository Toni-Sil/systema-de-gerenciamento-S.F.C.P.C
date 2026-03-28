import { describe, it, expect } from 'vitest';
import { formatCurrency, formatPercent, getAbcColor } from '@/lib/utils';

describe('formatCurrency', () => {
  it('formats BRL correctly', () => {
    const result = formatCurrency(1500);
    expect(result).toContain('1.500');
    expect(result).toContain('R$');
  });
});

describe('formatPercent', () => {
  it('formats percent with 1 decimal', () => {
    expect(formatPercent(0.856)).toBe('85.6%');
  });
});

describe('getAbcColor', () => {
  it('returns green for A class', () => {
    expect(getAbcColor('A')).toContain('green');
  });
  it('returns yellow for B class', () => {
    expect(getAbcColor('B')).toContain('yellow');
  });
  it('returns red for C class', () => {
    expect(getAbcColor('C')).toContain('red');
  });
});
