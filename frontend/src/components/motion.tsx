/**
 * PageTransition — wraps page content with Framer Motion enter/exit animations.
 * Use as the root wrapper of any page component.
 */
import { motion } from 'framer-motion';
import { ReactNode } from 'react';

interface Props { children: ReactNode; className?: string; }

const variants = {
  hidden:  { opacity: 0, y: 16, scale: 0.99 },
  visible: { opacity: 1, y: 0,  scale: 1,    transition: { duration: 0.35, ease: 'easeOut' as const } },
  exit:    { opacity: 0, y: -8, scale: 0.99, transition: { duration: 0.2,  ease: 'easeIn' as const } },
};

export function PageTransition({ children, className = '' }: Props) {
  return (
    <motion.div
      variants={variants}
      initial="hidden"
      animate="visible"
      exit="exit"
      className={className}
    >
      {children}
    </motion.div>
  );
}

/**
 * FadeIn — staggered children animation.
 * Wrap a list and each child fades + slides in with a delay.
 */
const containerVariants = {
  hidden: {},
  visible: { transition: { staggerChildren: 0.07, delayChildren: 0.05 } },
};

const childVariants = {
  hidden:  { opacity: 0, y: 20 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.4, ease: 'easeOut' as const } },
};

export function StaggerList({ children, className = '' }: Props) {
  return (
    <motion.div
      variants={containerVariants}
      initial="hidden"
      animate="visible"
      className={className}
    >
      {children}
    </motion.div>
  );
}

export function StaggerItem({ children, className = '' }: Props) {
  return (
    <motion.div variants={childVariants} className={className}>
      {children}
    </motion.div>
  );
}

/**
 * ScaleOnHover — Adds spring pop on hover to any element.
 */
export function ScaleOnHover({ children, className = '' }: Props) {
  return (
    <motion.div
      whileHover={{ scale: 1.025 }}
      whileTap={{ scale: 0.97 }}
      transition={{ type: 'spring', stiffness: 400, damping: 25 }}
      className={className}
    >
      {children}
    </motion.div>
  );
}

/**
 * SlideIn — Slides from a direction on mount.
 */
export function SlideIn({
  children,
  from = 'bottom',
  className = '',
  delay = 0,
}: Props & { from?: 'bottom' | 'left' | 'right' | 'top'; delay?: number }) {
  const dir = {
    bottom: { y: 30 },
    top:    { y: -30 },
    left:   { x: -30 },
    right:  { x: 30 },
  }[from];

  return (
    <motion.div
      initial={{ opacity: 0, ...dir }}
      animate={{ opacity: 1, y: 0, x: 0 }}
      transition={{ duration: 0.45, ease: [0.22, 1, 0.36, 1], delay }}
      className={className}
    >
      {children}
    </motion.div>
  );
}

/**
 * AnimatedCounter — Counts up to a numeric value on mount.
 */
import { useEffect, useRef } from 'react';

export function AnimatedCounter({
  value,
  prefix = '',
  suffix = '',
  duration = 1200,
  className = '',
}: {
  value: number;
  prefix?: string;
  suffix?: string;
  duration?: number;
  className?: string;
}) {
  const ref = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const start = 0;
    const end = value;
    const startTime = performance.now();

    const tick = (now: number) => {
      const elapsed = now - startTime;
      const progress = Math.min(elapsed / duration, 1);
      // ease-out cubic
      const eased = 1 - Math.pow(1 - progress, 3);
      const current = Math.round(start + (end - start) * eased);
      el.textContent = `${prefix}${current.toLocaleString('pt-BR')}${suffix}`;
      if (progress < 1) requestAnimationFrame(tick);
    };

    requestAnimationFrame(tick);
  }, [value, prefix, suffix, duration]);

  return <span ref={ref} className={className}>{prefix}0{suffix}</span>;
}
