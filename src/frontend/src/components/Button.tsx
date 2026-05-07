import type { ButtonHTMLAttributes } from "react";
import { cn } from "../lib/utils";
import { InlineSpinner } from "./LoadingSpinner";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "secondary" | "danger" | "ghost";
  size?: "sm" | "md" | "lg";
  loading?: boolean;
}

const variants = {
  primary: "bg-violet-600 hover:bg-violet-500 text-white border-transparent",
  secondary: "bg-zinc-800 hover:bg-zinc-700 text-zinc-200 border-zinc-700",
  danger: "bg-red-600 hover:bg-red-500 text-white border-transparent",
  ghost:
    "bg-transparent hover:bg-zinc-800 text-zinc-400 hover:text-zinc-200 border-transparent",
};

const sizes = {
  sm: "px-2.5 py-1 text-xs",
  md: "px-3.5 py-1.5 text-sm",
  lg: "px-5 py-2 text-base",
};

export function Button({
  variant = "primary",
  size = "md",
  loading,
  disabled,
  className,
  children,
  ...props
}: ButtonProps) {
  return (
    <button
      disabled={disabled || loading}
      className={cn(
        "inline-flex items-center gap-1.5 rounded-lg border font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-500 disabled:opacity-50 disabled:cursor-not-allowed",
        variants[variant],
        sizes[size],
        className,
      )}
      {...props}
    >
      {loading && <InlineSpinner />}
      {children}
    </button>
  );
}
