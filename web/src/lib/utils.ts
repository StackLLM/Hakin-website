import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

// Assemble des classes Tailwind (conflits résolus par tailwind-merge).
// Les formats de prix et de date sont dans `lib/format.ts` (DH) et `features/admin/commun.tsx`.
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
